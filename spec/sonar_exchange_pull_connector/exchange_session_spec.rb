require 'spec_helper'

# This file is copied and adapted from Trampoline Sonar code base:
#   sonar-web/spec/commands/extract_themes_from_message_command_spec.rb
#   sonar-web/spec/lib/exchange_connector_spec.rb

describe Sonar::Connector::ExchangeSession do
  
  def stub_message(raw="RFC822 content")
    message = Object.new
    message.instance_eval do
      def <=>(other)
        self.object_id <=> other.object_id
      end
    end
        
    stub(message).to_s{"raw: #{raw}"}
    stub(message).raw{raw}
    message
  end
  
  def stub_folder(name="folder", messages=[], folders=[])
    folder = Object.new
    stub(folder).to_s{name}
    stub(folder).message_hrefs(is_a(Regexp)){messages}
    stub(folder).folders{folders}
    folder
  end
  
  before do
    @config = {
      :dav_uri => 'dav_uri', 
      :owa_uri => 'owa_uri', 
      :username => 'username',
      :password => 'password',
      :mailbox => 'mailbox'
    }
    @session = Sonar::Connector::ExchangeSession.new(@config)
  end
  
  describe "initialize" do
    it "should set params" do
      [:dav_uri, :owa_uri, :username, :password, :mailbox].each{|p|
        @session.send(p).should == @config[p]
      }
    end
  end
  
  describe "open_session" do
    it "should call RExchange::open with a constructed url and the given username, password and mailbox" do
      mock(@session).make_url(anything, anything){"some_url"}
      mock(RExchange).open("some_url", @config[:owa_uri], @config[:username], @config[:password] )
      @session.open_session
    end
    
    it "should return an RExchange::Session object" do
      @session.open_session.should be_instance_of(RExchange::Session)
    end
  end
  
  describe "test_connection" do
    it "should call open_session with the given args and call folders on the root folder" do
      mock(@rexchange_session = Object.new).folders
      mock(@session).open_session{@rexchange_session}
      @session.test_connection
    end
  end
  
  describe "get_messages" do
    it "should call fetch_messages with params" do
      folder = Object.new
      archive_folder = Object.new
      batch_limit = 10
      href_regex = /foo/
      mock(@session).fetch_messages(folder, archive_folder, batch_limit, href_regex, [], is_a(Proc))
      @session.get_messages(:folder=>folder, :archive_folder=>archive_folder, :batch_limit=>batch_limit, :href_regex=>href_regex){}
    end
  end
  
  describe "fetch_messages" do
    before do
      @messages = 5.times.map{ stub_message }
      @inbox = stub_folder "inbox", @messages
      @archive = stub_folder "archive"
    end
    
    it "should return messages if current folder is the archive folder" do
      @session.send(:fetch_messages, @inbox, @inbox, 10, //, []).should == []
    end
    
    it "should retrieve mails" do
      @session.send(:fetch_messages, @inbox, @archive, 10, //, []).should == @messages
    end
    
    it "should yield to block" do
      processed_messages = []
      @session.send(:fetch_messages, @inbox, @archive, 10, //, []){|message|
        processed_messages << message
      }
      processed_messages.should == @messages
    end
    
    it "should obey batch_limit" do
      @session.send(:fetch_messages, @inbox, @archive, 3, //, []).should == @messages[0...3]
    end
    
    it "should descend subfolders" do
      inbox_messages = 5.times.map {stub_message }
      inbox_foo_messages = 5.times.map {stub_message }
      inbox_bar_messages = 5.times.map {stub_message }
      inbox_foo_baz_messages = 5.times.map {stub_message }
      
      all_messages = inbox_messages + inbox_foo_messages + inbox_bar_messages + inbox_foo_baz_messages
      
      # deepest folder
      inbox_foo_baz = stub_folder "inbox_foo_baz", inbox_foo_baz_messages, []
      
      # 2x mid-level folders, one with a sub-folder
      inbox_foo = stub_folder "inbox_foo", inbox_foo_messages, [inbox_foo_baz]
      inbox_bar = stub_folder "inbox_bar", inbox_bar_messages, []
      
      # root folder with 2x sub-folders
      inbox = stub_folder "inbox", inbox_messages, [inbox_foo, inbox_bar]
      
      @session.send(:fetch_messages, inbox, @archive, 20, //, []).sort.should == all_messages.sort
    end
      
    
  end
  
  
  describe "old specs" do
    
    # def create_mocks
    #   @content = "fake rfc822 content"
    #   mock(@archive = Object.new)
    #   
    #   mock(@href1 = Object.new).raw{ @content }
    #   mock(@href2 = Object.new).raw{ raise "EXCEPTION" }
    #   
    #   @was_href3_fetched = false
    #   mock(@href3 = Object.new).raw{ @was_href3_fetched = false; @content }
    #   
    #   hrefs = [@href1, @href2, @href3]
    #   
    #   mock(sub_folder_1 = Object.new).folders.at_least(1){ [] }
    #   
    #   mock(sub_folder_2_2 = Object.new).folders.at_least(1){ raise "EXCEPTION" }
    #   mock(sub_folder_2 = Object.new).folders.at_least(1){ [sub_folder_2_2] }
    #   
    #   @was_sub_folder_3_visited = false
    #   mock(sub_folder_3 = Object.new).folders.at_least(1){@was_sub_folder_3_visited = true; []}
    #   
    #   stub(inbox = Object.new).archive{ @archive }
    #   stub(inbox).folders{ [sub_folder_1, sub_folder_2, sub_folder_3] }
    #   stub(inbox).message_hrefs.with(instance_of Regexp){ hrefs }
    #   
    #   stub(root_folder = Object.new).inbox{ inbox }
    #   
    #   stub(RExchange).open(){ root_folder }
    # end
    
    before do
      @settings = exchange_connection_settings( '2007' )
      pending
    end
  
    it "should get email content from exchange and write it to a file in a sub-directory of staging dir" do 
      create_mocks
      @email_account = ExchangeAccount.spec_create!(:enabled => true, :settings => @settings.to_yaml)
    
      staging_dir = nil # closure local
      
      # a sub-directory gets created in the staging dir
      FileUtils.should_receive( :mkdir_p ).and_return{ |p| staging_dir = p; raise unless p =~ /\/foo\/.+/; nil }
      @href1.should_receive(:mark_as_read)
      @href1.should_receive(:move_to).with(@archive)
      
      # a file gets written in that dir with the contents of href1
      href1_io = mock( "href1" )
      href1_io.should_receive( :write ).at_least(:once).with( FAKE_CONTENT ).and_return( FAKE_CONTENT.length )
      
      File.should_receive( :open ).at_least(:once).and_return{ |p, mode, block|
        raise unless mode = "w"
        raise unless p =~ /\/foo\/.+/
      
        block.call( href1_io )
        href1_io
      }
      ExchangeRetrieveCommand.new.execute( 'email_account_id' => @email_account.id,
              'staging_dir_parent' => "/foo" )
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
  end
    
end