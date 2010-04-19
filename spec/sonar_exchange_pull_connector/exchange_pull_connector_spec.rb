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
  
  describe "make_dirs" do
    it "should create working dir" do
      File.directory?(@connector.working_dir).should be_false
      @connector.send(:make_dirs)
      File.directory?(@connector.working_dir).should be_true
    end
    
    it "should create complete dir" do
      File.directory?(@connector.complete_dir).should be_false
      @connector.send(:make_dirs)
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
  
  
end