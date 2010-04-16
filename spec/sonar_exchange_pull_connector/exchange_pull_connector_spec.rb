require 'spec_helper'

describe Sonar::Connector::ExchangePullConnector do
  before do
    setup_valid_config_file
    @base_config = Sonar::Connector::Config.load(valid_config_filename)
    @config = {
      'type'=>Sonar::Connector::ExchangePullConnector, 
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
  end
  
  describe "class methods" do
    before(:all) do
      @settings = exchange_connection_settings('2007')
    end

    describe "test_connection" do
      it "should call open_session with the given args and call folders on the root folder" do
        mock(@mock_session = Object.new).folders{ [] }
        mock(Sonar::Connector::ExchangePullConnector).open_session(@settings){ @mock_session }
        Sonar::Connector::ExchangePullConnector.test_connection(@settings)
      end
    end
    
    describe "open_session" do
      it "should call RExchange::open with a constructed url and the given username, password and mailbox" do
        mock(Sonar::Connector::ExchangePullConnector).make_url(@settings){"blart"}
        mock(RExchange).open("blart", @settings['owa_uri'], @settings['username'], @settings['password'] )
        Sonar::Connector::ExchangePullConnector.open_session(@settings)
      end
      
      it "should return an RExchange::Session object" do
        session = Sonar::Connector::ExchangePullConnector.open_session(@settings)
        session.class.should == RExchange::Session
      end
    end
    
  end
  
  describe "parse" do
    it "should set connection properties" do
      @connector = Sonar::Connector::ExchangePullConnector.new(@config, @base_config)
      
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
  end
  
end