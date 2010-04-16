require 'spec_helper'

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
end