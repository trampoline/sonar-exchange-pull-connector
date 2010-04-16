require 'spec_helper'

# This file is copied and adapted from Trampoline Sonar code base:
#   sonar-web/spec/commands/extract_themes_from_message_command_spec.rb
#   sonar-web/spec/lib/exchange_connector_spec.rb

describe Sonar::Connector::ExchangeSession do
  describe "class methods" do
    before(:all) do
      @settings = exchange_connection_settings('2007')
    end

    describe "test_connection" do
      it "should call open_session with the given args and call folders on the root folder" do
        mock(@mock_session = Object.new).folders{ [] }
        mock(Sonar::Connector::ExchangeSession).open_session(@settings){ @mock_session }
        Sonar::Connector::ExchangeSession.test_connection(@settings)
      end
    end
    
    describe "open_session" do
      it "should call RExchange::open with a constructed url and the given username, password and mailbox" do
        mock(Sonar::Connector::ExchangeSession).make_url(@settings){"blart"}
        mock(RExchange).open("blart", @settings['owa_uri'], @settings['username'], @settings['password'] )
        Sonar::Connector::ExchangeSession.open_session(@settings)
      end
      
      it "should return an RExchange::Session object" do
        session = Sonar::Connector::ExchangeSession.open_session(@settings)
        session.class.should == RExchange::Session
      end
    end
  end
  
  def create_mocks
    @content = "fake rfc822 content"
    mock(@archive = Object.new)
    
    mock(@href1 = Object.new).raw{ @content }
    mock(@href2 = Object.new).raw{ raise "EXCEPTION" }
    
    @was_href3_fetched = false
    mock(@href3 = Object.new).raw{ @was_href3_fetched = false; @content }
    
    hrefs = [@href1, @href2, @href3]
    
    mock(sub_folder_1 = Object.new).folders.at_least(1){ [] }
    
    mock(sub_folder_2_2 = Object.new).folders.at_least(1){ raise "EXCEPTION" }
    mock(sub_folder_2 = Object.new).folders.at_least(1){ [sub_folder_2_2] }
    
    @was_sub_folder_3_visited = false
    mock(sub_folder_3 = Object.new).folders.at_least(1){@was_sub_folder_3_visited = true; []}
    
    stub(inbox = Object.new).archive{ @archive }
    stub(inbox).folders{ [sub_folder_1, sub_folder_2, sub_folder_3] }
    stub(inbox).message_hrefs.with(instance_of Regexp){ hrefs }
    
    stub(root_folder = Object.new).inbox{ inbox }
    
    stub(RExchange).open(){ root_folder }
  end
  
  before do
    @settings = exchange_connection_settings( '2007' )
  end
  
  it "should get email content from exchange and write it to a file in a sub-directory of staging dir" do 
    create_mocks
    # @email_account = ExchangeAccount.spec_create!(:enabled => true, :settings => @settings.to_yaml)
    # 
    # staging_dir = nil # closure local
    #   
    # # a sub-directory gets created in the staging dir
    # FileUtils.should_receive( :mkdir_p ).and_return{ |p| staging_dir = p; raise unless p =~ /\/foo\/.+/; nil }
    # @href1.should_receive(:mark_as_read)
    # @href1.should_receive(:move_to).with(@archive)
    #   
    # # a file gets written in that dir with the contents of href1
    # href1_io = mock( "href1" )
    # href1_io.should_receive( :write ).at_least(:once).with( FAKE_CONTENT ).and_return( FAKE_CONTENT.length )
    #   
    # File.should_receive( :open ).at_least(:once).and_return{ |p, mode, block|
    #   raise unless mode = "w"
    #   raise unless p =~ /\/foo\/.+/
    #   
    #   block.call( href1_io )
    #   href1_io
    # }
    # ExchangeRetrieveCommand.new.execute( 'email_account_id' => @email_account.id,
    #         'staging_dir_parent' => "/foo" )
  end
    
  it "should schedule an ImportEmailDirectory command" do
    create_mocks
    FileUtils.stub!(:mkdir_p).and_return(true)
    href1_io = mock( "href1" )
    href1_io.stub!( :write ).and_return( FAKE_CONTENT.length )
    File.stub!( :open ).and_return(href1_io)

    @email_account = ExchangeAccount.spec_create!(:enabled => true, :settings => @settings.to_yaml)
    
    cmd = ExchangeRetrieveCommand.new
    cmd.should_receive( :schedule_import_command ).with( any_args() ).once
    
    cmd.execute( 'email_account_id' => @email_account.id,
            'staging_dir_parent' => "/foo" )
  end
  
    it "should not import emails if the ExchangeAccount is disabled" do
      @email_account = ExchangeAccount.spec_create!(:enabled => true, :settings => @settings.to_yaml, :enabled => false)
      command = ExchangeRetrieveCommand.new
      command.should_not_receive(:process_emails)
      command.execute( 'email_account_id' => @email_account.id )
    end
    
    it "should schedule the import command even if exchange ops raise an exception" do
      create_mocks
      @email_account = ExchangeAccount.spec_create!(:enabled => true, :settings => @settings.to_yaml)
    
      File.should_receive( :open ).at_least(:once).and_return{ |p,mode,block|
        raise Exception.new( "boo" )
      }
    
      cmd = ExchangeRetrieveCommand.new
      cmd.should_receive( :schedule_import_command )
      
      cmd.execute( 'email_account_id' => @email_account.id )
    end
    
    it "should move messages to archive folder if 'delete_processed_messages' is not set in account settings" do
      create_mocks
      @email_account = ExchangeAccount.spec_create!(:enabled => true, :settings => @settings.to_yaml)
      @href1.should_receive(:mark_as_read)
      @href1.should_receive(:move_to).with(@archive)
    
      @href3.should_receive(:mark_as_read)
      @href3.should_receive(:move_to).with(@archive)
      ExchangeRetrieveCommand.new.execute('email_account_id' => @email_account.id)
      @was_sub_folder_3_visited.should == true
      @was_href3_fetched.should == true
    end
    
    it "should move messages to archive folder if 'delete_processed_messages' is set to false in account settings" do
      create_mocks
      @settings['delete_processed_messages'] = '0'
      @email_account = ExchangeAccount.spec_create!(:enabled => true, :settings => @settings.to_yaml)
      @href1.should_receive(:mark_as_read)
      @href1.should_receive(:move_to).with(@archive)
    
      @href3.should_receive(:mark_as_read)
      @href3.should_receive(:move_to).with(@archive)
      ExchangeRetrieveCommand.new.execute('email_account_id' => @email_account.id)
    end
    
    it "should get emails content from exchange deleting them if 'delete_processed_messages' is set to true in account settings" do
      create_mocks
      @settings['delete_processed_messages'] = '1'
      @email_account = ExchangeAccount.spec_create!(:enabled => true, :settings => @settings.to_yaml)
      @href1.should_receive(:mark_as_read)
      @href1.should_receive(:delete!)
    
      @href3.should_receive(:mark_as_read)
      @href3.should_receive(:delete!)
      ExchangeRetrieveCommand.new.execute('email_account_id' => @email_account.id)
    end
    
    describe "schedule_import_command" do
      before(:each) do
        @import_dir = '/test/dir'
        @journal_acct_dir = '/test/journal/account/dir'
      end
      
      it "should schedule an ImportEmailDirectoryCommand if is_journal_account is false" do     
        ImportEmailDirectoryCommand.should_receive(:schedule!).with( 'dir'=> @import_dir )
        ExchangeRetrieveCommand.new.schedule_import_command( @import_dir, @journal_acct_dir, false )
      end
      
      it "should schedule an ExtractAttachmentsFromRfc822DirectoryCommand if is_journal_account is true" do
        ExtractAttachmentsFromRfc822DirectoryCommand.should_receive(:schedule!).with( 'dir'=> @import_dir, 'output_dir' => @journal_acct_dir )
        ExchangeRetrieveCommand.new.schedule_import_command( @import_dir, @journal_acct_dir, true )
      end
      
    end
  
end