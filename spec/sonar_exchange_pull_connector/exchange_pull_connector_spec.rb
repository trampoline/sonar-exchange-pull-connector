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
      'owa_uri'  => 'https://exchangevm/owa/auth/owaauth.dll',
      'username' => 'journal',
      'password' => 'D33pfried',
      'mailbox'  => 'journal@trampolan.local',
      'delete_processed_messages' => false,
      'is_journal_account' => false
    }
    @connector = Sonar::Connector::ExchangePullConnector.new(@config, @base_config)
  end
  
  describe "parse" do
    it "should set connection properties" do
      %W{dav_uri owa_uri username password mailbox delete_processed_messages is_journal_account}.each{|p|
        @connector.send(p).should == @config[p]
      }
    end
    
    it "should require dav_uri, owa_uri, username and mailbox" do
      %W{dav_uri owa_uri username mailbox}.each{|p|
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
      File.basename(f).should match(/working_[0..9]?/)
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
    it "should create valid JSON" do
      mail = Object.new
      stub(mail).raw{ "raw content" }
      
      json = @connector.send :mail_to_json, mail
      
      recon_mail = JSON.parse json
      recon_mail["raw"].should == mail.raw
    end
  end
  
  describe "action" do
    
    describe "connecting" do
      it "should raise error if connection error" do
        mock(@session = Object.new).open_session
        mock(@session).test_connection{raise RExchange::RException.new("foo", "bar", Exception.new)}
        mock(Sonar::Connector::ExchangeSession).new(anything){@session}
        
        lambda{
          @connector.action
        }.should raise_error
      end
    end
  end
  
end