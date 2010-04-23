require 'spec_helper'

describe Sonar::Connector::ExchangePullConnector do
  before do
    setup_valid_config_file
    @base_config = Sonar::Connector::Config.load(valid_config_filename)
    @config = {
      'type'=>'Sonar::Connector::ExchangePullConnector', 
      'name'=>'exchange', 
      'repeat_delay'=> 1,
      'dav_uri'  => 'https://exchangevm/Exchange/',
      'auth_type'=> 'form',
      'owa_uri'  => 'https://exchangevm/owa/auth/owaauth.dll',
      'username' => 'journal',
      'password' => 'D33pfried',
      'mailbox'  => 'journal@trampolan.local',
      'delete_processed_messages' => false,
      'is_journal_account' => false
    }
    @connector = Sonar::Connector::ExchangePullConnector.new(@config, @base_config)

    # and set up a queue or #action and several other methods will complain
    @connector.instance_eval do
      @queue = []
    end
    
  end
  
  describe "parse" do
    it "should set connection properties" do
      %W{dav_uri owa_uri username password mailbox delete_processed_messages is_journal_account}.each{|p|
        @connector.send(p).should == @config[p]
      }
    end
    
    it "should require dav_uri, username and mailbox" do
      %W{dav_uri username mailbox}.each{|p|
        lambda{
          @connector = Sonar::Connector::ExchangePullConnector.new(@config.merge({p=>nil}), @base_config)
        }.should raise_error(Sonar::Connector::InvalidConfig, /#{p}.*cannot be blank/)
      }
    end
    
    it "should set default retrieve_batch_size" do
      @config['retrieve_batch_size'].should be_nil
      @connector = Sonar::Connector::ExchangePullConnector.new(@config, @base_config)
      @connector.retrieve_batch_size.should == 1000
    end
    
    it "should set let config override default retrieve_batch_size" do
      @config['retrieve_batch_size'] = 99
      @connector = Sonar::Connector::ExchangePullConnector.new(@config, @base_config)
      @connector.retrieve_batch_size.should == 99
    end
    
    describe "auth_type" do
      it "should raise error when type is form and owa_uri not supplied" do
        pending
      end
      it "should set owa_uri when type is form" do
        pending
      end
      it "should raise error when type is basic and owa_uri is supplied" do
        pending
      end
      it "should set owa_uri to nil for basic" do
        pending
      end
    end
    
  end
  
  describe "create_dirs" do
    it "should create working dir" do
      File.directory?(@connector.working_dir).should be_false
      @connector.send(:create_dirs)
      File.directory?(@connector.working_dir).should be_true
    end
    
    it "should create complete dir" do
      File.directory?(@connector.complete_dir).should be_false
      @connector.send(:create_dirs)
      File.directory?(@connector.complete_dir).should be_true
    end
  end
  
  describe "create_timestamped_working_dir" do
    before do
      @t0 = Time.now
      mock(Time).now{@t0}
    end
    
    it "should create a working dir" do
      Dir[File.join @connector.working_dir, "*"].should be_empty
      @connector.send(:create_timestamped_working_dir)
      Dir[File.join @connector.working_dir, "*"].should_not be_empty
      
      f = Dir[File.join @connector.working_dir, "*"].first
      File.basename(f).should match(/working_\d+/)
    end
    
    it "should return the dir name" do
      File.directory?(@connector.send(:create_timestamped_working_dir)).should be_true
    end
  end
  
  describe "cleanup_working_dir" do
    before do
      @connector.send(:create_dirs)
    end
    
    it "should remove empty top-level dirs" do
      @top_dirs = ["foo", "bar"]
      @top_dirs.each { |d| FileUtils.mkdir_p(File.join @connector.working_dir, d) }
      
      @connector.send(:cleanup_working_dir)
      
      @top_dirs.each { |d| File.directory?(File.join @connector.working_dir, d).should be_false }
      @top_dirs.each { |d| File.directory?(File.join @connector.complete_dir, d).should be_false }
    end
    
    it "should move non-empty dirs if the dir contains a file" do
      subdir = File.join "foo", "some_temporary_subdir"
      FileUtils.mkdir_p(File.join @connector.working_dir, subdir)
      
      @connector.send(:cleanup_working_dir)
      
      File.directory?(File.join @connector.working_dir, subdir).should_not be_true
      File.directory?(File.join @connector.complete_dir, subdir).should be_true
    end
    
    it "should move non-empty dirs if the dir contains a dir" do
      content = "blart"
      FileUtils.mkdir_p File.join(@connector.working_dir, "foo")
      File.open(File.join(@connector.working_dir, "foo", "test.txt"), "w") {|f| f << content}
      
      @connector.send(:cleanup_working_dir)
      
      File.read(File.join @connector.complete_dir, "foo", "test.txt").should == content
    end
  end
  
  describe "mail_to_json" do
    before do
      @content = "raw RFC822 content"
      @t0 = Time.now
      @reconstituted_json = JSON.parse @connector.send(:mail_to_json, @content, @t0)
    end
    
    it "should contain base64-encoded raw mail contents" do
      @reconstituted_json["rfc822_base84"].should == Base64.encode64(@content)
    end
    
    it "should include name" do
      @reconstituted_json["name"].should == @connector.name
    end
    
    it "should have retrieved_at timestamp" do
      @reconstituted_json["retrieved_at"].should == @t0.to_s
    end
    
    it "should contain source_info" do
      @reconstituted_json["source_info"].should match(/#{@connector.class}.*#{@connector.name}.*#{@connector.dav_uri}.*#{@connector.mailbox}/)
    end
  end
  
  describe "archive_or_delete" do
    before do
      @message = Object.new
      @folder = Object.new
    end
    
    it "should archive when not delete_processed_messages" do
      dont_allow(@message).delete!
      mock(@message).move_to(@folder)
      @connector.send :archive_or_delete, @message, false, @folder
    end
    
    it "should delete when delete_processed_messages" do
      dont_allow(@message).move_to(anything)
      mock(@message).delete!
      @connector.send :archive_or_delete, @message, true, @folder
    end
    
    it "should recover from RException when moving" do
      mock(@message).move_to(anything){ raise stub_rexception }
      mock(@connector.log).warn(anything)
      lambda{
        @connector.send :archive_or_delete, @message, false, @folder
      }.should_not raise_error
    end
    
    it "should recover from RException when deleting" do
      mock(@message).delete!{ raise stub_rexception }
      mock(@connector.log).warn(anything)
      lambda{
        @connector.send :archive_or_delete, @message, true, @folder
      }.should_not raise_error
    end
    
  end
  
  describe "update_statistics" do
    it "should queue 3 updates" do
      mock(@connector.queue).push(is_a(Sonar::Connector::UpdateStatusCommand)).times(3)
      @connector.send :update_statistics, "last_connect_timestamp", "count_retrieved", "count_remaining"
    end
    
    it "should update last_connect_timetamp, count_retrieved and count_remaining" do
      stub(Sonar::Connector::UpdateStatusCommand).new
      
      t0 = Time.now
      @connector.send :update_statistics, t0, 0, "unknown"
      
      Sonar::Connector::UpdateStatusCommand.should have_received.new(@connector, "last_connect_timetamp", t0.to_s)
      Sonar::Connector::UpdateStatusCommand.should have_received.new(@connector, "count_retrieved", 0)
      Sonar::Connector::UpdateStatusCommand.should have_received.new(@connector, "count_remaining", "unknown")
    end
  end
  
  describe "write_to_file" do
    before do
      @content = "some content"
      @dir = @connector.send :create_timestamped_working_dir
      Dir[@dir+"/*"].should be_empty
      @connector.send(:write_to_file, @content, @dir, "message", ".json")
    end
    
    it "should write content to a file in the dir" do
      Dir[@dir+"/*"].size.should == 1
      f = Dir[@dir+"/*"].first
      File.read(f).should == @content
    end
    
    it "should create a timestamped filename" do
      f = Dir[@dir+"/*"].first
      File.basename(f).should match(/message_\d+\.json/)
    end
  end
  
  describe "extract_email" do
    before do
      @content = load_fixture_file "email_with_email_attachment.eml"
    end
    
    it "should return a parsed email" do
      mail = @connector.send :extract_email, @content
      mail.subject.should match(/Top-level email/)
    end
    
    it "should use first attachment if required" do
      mail = @connector.send :extract_email, @content, true
      mail.subject.should match(/This is an attachment/)
    end
    
    it "should return nil and log warning if the email doesn't parse" do
      mock(TMail::Mail).parse(@content){ raise TMail::SyntaxError.new}
      mock(@connector.log).warn(/couldn't parse an email/)
      @connector.send(:extract_email, @content).should be_nil
    end
    
    it "should return nil and log warning if use_first_attachment is specified but no attachment exists" do
      @content = load_fixture_file "email_without_attachment.eml"
      mock(@connector.log).warn(/there are no attachments on this mail/)
      @connector.send(:extract_email, @content, true).should be_nil
    end
  end
  
  describe "extract_header" do
    it "should return empty string if supplied empty string" do
      @connector.send(:extract_header, "").should == ""
    end
    
    it "should return the content if there is no double line break" do
      content = "foo bar baz \r\n  blah blah blah\r\n"
      @connector.send(:extract_header, content).should == content
    end
    
    it "should split on double \\r\\n" do
      content = "foo\r\n\r\nbar"
      @connector.send(:extract_header, content).should == "foo"
    end
    
    it "should split on double \\n" do
      content = "foo\n\nbar"
      @connector.send(:extract_header, content).should == "foo"
    end
    
  end
  
  describe "create_and_open_session" do
    before do
      @session_config = {
        :dav_uri => 'dav_uri', 
        :owa_uri => 'owa_uri', 
        :username => 'username',
        :password => 'password',
        :mailbox => 'mailbox'
      }
      
      @session = Sonar::Connector::ExchangeSession.new @session_config
      stub(@session).open_session
      stub(@session).test_connection{@root_folder}
      
      @root_folder = Object.new
      stub(@session).root_folder{@root_folder}
      
      stub(Sonar::Connector::ExchangeSession).new(anything){@session}
    end
    
    it "should raise error if connection error" do
      mock(@session).test_connection{raise stub_rexception}
      lambda{
        @connector.send :create_and_open_session
      }.should raise_error
    end
    
    it "should return a session on valid connect" do
      @connector.send(:create_and_open_session).should be_instance_of(Sonar::Connector::ExchangeSession)
    end
  end
  
  describe "ensure_archive_folder_exists" do
    it "should create the folder if it exists" do
      pending
    end
    
    it "should not create the folder if it already exists" do
      pending
    end
  end
  
  describe "extract_and_save" do
    before do
      @content = "content"
      @dir = "foo_dir"
      stub(@message = Object.new).raw{@content}
      stub(@tmail = Object.new).to_s{@content}
      stub(@connector).extract_email{@tmail}
      stub(@connector).mail_to_json
      stub(@connector).write_to_file
    end
    
    it "should generate tmail object from content" do
      mock(@connector).extract_email(@content, anything)
      @connector.send :extract_and_save, @message, @dir
    end
    
    it "should generate json" do
      mock(@connector).mail_to_json(@content, is_a(Time)){@content}
      @connector.send :extract_and_save, @message, @dir
    end
    
    it "should write to file" do
      stub(@connector).mail_to_json{@content}
      mock(@connector).write_to_file(@content, @dir, anything, anything)
      @connector.send :extract_and_save, @message, @dir
    end
    
    describe "header only" do
      it "should extract header when headers_only set" do
        mock(@connector).headers_only{true}
        mock(@connector).extract_header(@content){@content}
        @connector.send :extract_and_save, @message, @dir
      end
      
      it "should use full content when headers_only is not set" do
        mock(@connector).headers_only{false}
        dont_allow(@connector).extract_header(anything)
        @connector.send :extract_and_save, @message, @dir
      end
    end
  end
  
  
  describe "action" do
    before do
      @session_config = {
        :dav_uri => 'dav_uri', 
        :owa_uri => 'owa_uri', 
        :username => 'username',
        :password => 'password',
        :mailbox => 'mailbox'
      }
      
      @archive = stub_folder "archive"
      
      inbox_messages = 5.times.map {stub_message }
      @inbox = stub_folder "inbox", inbox_messages
      stub(@inbox).archive{@archive}
      
      @root_folder = Object.new
      stub(@root_folder).inbox{@inbox}
      
      @session = Sonar::Connector::ExchangeSession.new @session_config
      stub(@session).root_folder{@root_folder}
      stub(@connector).create_and_open_session{@session}

      stub(@connector).update_statistics
      stub(@connector).ensure_archive_folder_exists
      stub(@connector).extract_and_save
      stub(@connector).archive_or_delete
      
      # sanity check these mocks
      @session.root_folder.should_not be_nil
      @session.root_folder.inbox.should == @inbox
      @session.root_folder.inbox.archive.should == @archive
    end
    
    it "should process emails" do
      mock(@connector).extract_and_save(anything, anything).times(5)
      mock(@connector).archive_or_delete(anything, anything, @archive).times(5)
      @connector.action
    end
    
    it "should update statistics" do
      @connector.action
      @connector.should have_received.update_statistics("-", "-", "unknown")
      @connector.should have_received.update_statistics(is_a(Time), 5, 0)
    end
  end
  
end