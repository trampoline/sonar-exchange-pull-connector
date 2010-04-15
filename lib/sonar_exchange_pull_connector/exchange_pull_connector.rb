module Sonar
  module Connector
    class ExchangePullConnector < Sonar::Connector::Base
      
      class << self
        def test_connection( args = {} )
          # this is actually an RExchange::Session object, that doesn't actually connect
          # until you try to do something with it
          root_folder = open_session(args)
          folders = root_folder.folders
        end

        def open_session( args = {} )
          RExchange::open( make_url(args), args['owa_uri'], args['username'], args['password'])
        end

        def make_url( args = {} )
          "#{args['dav_uri']}/#{args['mailbox']}/"
        end
      end
      
      
      def parse(settings)
        
      end
      
      def action
        
      end
      
    end
  end
end
