module Sonar
  module Connector
    
    # Represents a connection to an Exchange server. Most of this code is imported from the 
    # Trampoline Sonar codebase, particularly files:
    #   sonar-web/lib/exchange_connector.rb
    #   sonar-web/app/commands/connectors/exchange_retrieve_command.rb
    #   sonar-web/app/commands/import/extract_attachments_from_rfc822_command.rb 
    class ExchangeSession
      
      attr_reader :dav_uri
      attr_reader :owa_uri
      attr_reader :username
      attr_reader :password
      attr_reader :mailbox
      attr_reader :root_folder
      attr_reader :log
      
      def initialize(args)
        @dav_uri = args[:dav_uri]
        @owa_uri = args[:owa_uri]
        @username = args[:username]
        @password = args[:password]
        @mailbox = args[:mailbox]
        @log = args[:log] || Logger.new(STDOUT)
      end
      
      # Create and open an Exchange session
      def open_session
        @root_folder = RExchange::open make_url(dav_uri, mailbox), owa_uri, username, password
      end
      
      # Helper function to create an Exchange DAV URL
      def make_url(dav_uri, mailbox)
        "#{dav_uri}/#{mailbox}/"
      end
      
      # RExchange::Session object doesn't actually connect
      # until you try to do something with it
      def test_connection
        open_session.folders
      end
      
      # Retrieve mail messages from Exchange mailbox, e.g.
      # get_mail(:folder=>root_folder.inbox, :archive_folder=>root_folder.inbox.archive, batch_limit=>100, :href_regex=>/foo/)
      # => [mail1, mail2, mail3 ... mailn]
      # Use a proc if you want to process mails in situ.
      # get_mail(:folder=>root_folder.inbox, :archive_folder=>root_folder.inbox.archive, batch_limit=>100, :href_regex=>/foo/){|mail|
      #   #process mail
      # }
      def get_messages(params, &proc)
        folder, archive_folder, batch_limit, href_regex = [:folder, :archive_folder, :batch_limit, :href_regex].map do |field|
          raise ArgumentError("#{field} is a required parameter") unless params[field]
          params[field]
        end
        
        fetch_messages folder, archive_folder, batch_limit, href_regex, [], proc
      end
      
      private
      
      # Recursive message retrieval. 
      # Descends into subfolders until limit has been reached. Should only be used by #get_mail.
      def fetch_messages(folder, archive_folder, batch_limit, href_regex, &proc)
        messages = []
        
        if folder == archive_folder # don't descend into archive folder
          log.info "skipping folder '#{folder}' because it's the archive folder"
          return messages
        end
        
        # first, retrieve messages in the current folder, and return if we hit the limit
        message_hrefs = folder.message_hrefs href_regex
        log.info "Total number of messages in folder '#{folder}' is: #{message_hrefs.size}"
        
        message_hrefs.each do |message|
          begin
            message.raw # trigger the fetch of the raw data
            messages << message
            yield message if proc
            return messages if messages.size >= batch_limit
          rescue RExchange::RException => e
            log.warn "There was a problem retrieving message from Exchange: " + e.message + "\n" + e.backtrace.join("\n")
          end
        end
        
        begin
          # then descend into the current folder's subfolders
          folder.folders.each do |sub_folder|
            return messages if messages.size >= batch_limit
            messages += fetch_messages(sub_folder, archive_folder, batch_limit-messages.size, href_regex, &proc)
          end
        rescue RExchange::RException => e
          log.warn "There was a problem listing subfolders with Exchange: " + e.message + "\n" + e.backtrace.join("\n")
          return messages
        end
        
        messages
      end
        
    end
  end
end