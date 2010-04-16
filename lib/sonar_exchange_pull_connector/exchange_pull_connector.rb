module Sonar
  module Connector
    class ExchangePullConnector < Sonar::Connector::Base
      
      attr_reader :dav_uri
      attr_reader :owa_uri
      attr_reader :username
      attr_reader :password
      attr_reader :mailbox
      attr_reader :delete_processed_messages
      attr_reader :is_journal_account
      
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
        @dav_uri = settings["dav_uri"]
        @owa_uri = settings["owa_uri"]
        @username = settings["username"]
        @password = settings["password"]
        @mailbox = settings["mailbox"]
        @delete_processed_messages = settings["delete_processed_messages"] == true
        @is_journal_account = settings["is_journal_account"] == true
        
        # validate that the key params are present
        [:dav_uri, :owa_uri, :username, :mailbox].each {|param|
          raise Sonar::Connector::InvalidConfig.new("Connector #{self.name}: parameter '#{param.to_s}' cannot be blank.") if self.send(param).blank?
        }
      end
      
      def action
        
      end
      
    end
  end
end
