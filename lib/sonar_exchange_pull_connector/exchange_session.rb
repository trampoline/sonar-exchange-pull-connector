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
      
      # def process_emails(message_mails, archive_folder, staging_dir, delete_messages=false)
      #   
      #   logger.info("Writing #{message_mails.size} messages to #{staging_dir.to_s}")
      #   
      #   message_mails.each_with_index do |(message, mail), i|
      #     begin
      #       fname =  File.join( staging_dir, "#{i.to_s}.rfc822")
      #       f = File.open( fname, "w") do |io|
      #         io.write( mail )
      #         logger.info( "message# #{i+1} (#{message}) written to #{fname}")
      #       end
      #       message.mark_as_read
      #       if delete_messages
      #         message.delete!
      #         logger.info("message# #{i+1} (#{message}) deleted on exchange")
      #       else
      #         message.move_to archive_folder
      #         logger.info("message# #{i+1} (#{message}) moved to archive")
      #       end
      #     rescue Exception => e
      #       logger.warn( "There was a problem moving message to archive : #{e.inspect}. #{e.backtrace.join("\n")}" )
      #     end
      #   end
      #   
      #   message_mails.size
      # end
      
      private
      
      # Recursive mail retrieval. Descends into subfolders until limit has been reached.
      # Only to be used by get_mail.
      def fetch_messages(folder, archive_folder, batch_limit, href_regex, messages = [], &proc)
        
        if folder == archive_folder # don't descend into archive folder
          log.info "skipping folder '#{folder}' because it's the archive folder"
          return messages
        end
        
        # first, retrieve messages in the current folder, and return if we hit the limit
        message_hrefs = folder.message_hrefs href_regex
        log.info "Total number of messages in folder '#{folder}' is: #{message_hrefs.size}"
        
        message_hrefs.each do |message|
          begin
            messages << message
            yield message if proc
            return messages if messages.size >= batch_limit
          rescue Exception => e
            log.warn "There was a problem retrieving message from Exchange: " + e.message + "\n" + e.backtrace.join("\n")
          end
        end
        
        # then descend into the current folder's subfolders
        folder.folders.each do |sub_folder|
          return messages if messages.size >= batch_limit
          messages += messages + fetch_messages(sub_folder, archive_folder, batch_limit, href_regex, messages, proc)
        end
        
        messages
        
      rescue Exception => e
        log.warn "There was a problem communicating with Exchange: " + e.message + "\n" + e.backtrace.join("\n")
        return messages
      end
        
    end
  end
end