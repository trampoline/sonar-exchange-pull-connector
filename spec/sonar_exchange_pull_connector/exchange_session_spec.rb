require 'spec_helper'

# This file is copied and adapted from Trampoline Sonar code base:
#   sonar-web/spec/commands/extract_themes_from_message_command_spec.rb
#   sonar-web/spec/lib/exchange_connector_spec.rb

describe Sonar::Connector::ExchangeSession do
  
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
      mock(@session).fetch_messages(folder, archive_folder, batch_limit, href_regex)
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
      @session.send(:fetch_messages, @inbox, @inbox, 10, //).should == []
    end
    
    it "should retrieve mails" do
      @session.send(:fetch_messages, @inbox, @archive, 10, //).should == @messages
    end
    
    it "should yield to block" do
      processed_messages = []
      @session.send(:fetch_messages, @inbox, @archive, 10, //){|message|
        processed_messages << message
      }
      processed_messages.should == @messages
    end
    
    it "should obey batch_limit" do
      @session.send(:fetch_messages, @inbox, @archive, 3, //).should == @messages[0...3]
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
      
      @session.send(:fetch_messages, inbox, @archive, 100, //).sort.should == all_messages.sort
    end
    
    it "should continue if a single mail raises an error" do
      m1, m3 = stub_message, stub_message
      m2 = stub_message
      stub(m2).raw{raise stub_rexception}
      stub(@inbox).message_hrefs(is_a(Regexp)){ [m1, m2, m3] }
      @session.send(:fetch_messages, @inbox, @archive, 10, //).should == [m1, m3]
    end
    
    it "should recover if folder retrieve raises an error" do
      @inbox = stub_folder "inbox", @messages, []
      mock(@inbox).folders{raise stub_rexception}
      @session.send(:fetch_messages, @inbox, @archive, 10, //).should == @messages
    end
    
  end
end