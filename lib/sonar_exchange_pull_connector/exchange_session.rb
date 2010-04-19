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
      
      def initialize(args)
        @dav_uri = args[:dav_uri]
        @owa_uri = args[:owa_uri]
        @username = args[:username]
        @password = args[:password]
        @mailbox = args[:mailbox]
      end
      
      def open_session
        @root_folder = RExchange::open make_url(dav_uri, mailbox), owa_uri, username, password
      end
      
      def make_url(dav_uri, mailbox)
        "#{dav_uri}/#{mailbox}/"
      end
      
      def test_connection
        # RExchange::Session object doesn't actually connect
        # until you try to do something with it
        open_session.folders
      end
      
      def fetch_emails(folder, archive_folder, batch_limit, href_regex)
        $stderr << "#{folder}\n#{archive_folder}\n#{batch_limit}\n#{href_regex}\n"
        message_mails = []
        if (folder != archive_folder)
          logger.info("descending into folder: #{folder}")
          begin
            message_hrefs = folder.message_hrefs(href_regex)
            logger.info("Total number of messages in folder is: #{message_hrefs.size}")
            message_hrefs.each_with_index do |message, index|
              begin
                logger.info("getting message# #{index+1} (#{message}) from current batch #{batch_limit} (already processed #{message_mails.size})")
                message_mails << [message, message.raw]
              rescue Exception => e
                logger.warn( "There was a problem getting message from exchange : #{e.inspect}. #{e.backtrace.join("\n")}" )
              end
              break if message_mails.size >= batch_limit
            end
          rescue Exception => e
            logger.warn( "There was a problem getting message from exchange : #{e.inspect}." )
          end
          begin
            folder.folders.each{|sub_folder|
              $stderr << "#{sub_folder}\n"
              if message_mails.size >= batch_limit
                $stderr << "breaking: #{message_mails.size}, #{batch_limit}\n"
                break
              end
              message_mails = message_mails + fetch_emails(sub_folder, archive_folder, batch_limit-message_mails.size, href_regex)
            }
          rescue Exception => e
            logger.warn( "There was a problem with listing subfolders of the current one : #{e.inspect}. #{e.backtrace.join("\n")}" )
          end
        end
        message_mails
      end
      
      
      def process_emails(message_mails, archive_folder, staging_dir, delete_messages=false)
        
        logger.info("Writing #{message_mails.size} messages to #{staging_dir.to_s}")
        
        message_mails.each_with_index do |(message, mail), i|
          begin
            fname =  File.join( staging_dir, "#{i.to_s}.rfc822")
            f = File.open( fname, "w") do |io|
              io.write( mail )
              logger.info( "message# #{i+1} (#{message}) written to #{fname}")
            end
            message.mark_as_read
            if delete_messages
              message.delete!
              logger.info("message# #{i+1} (#{message}) deleted on exchange")
            else
              message.move_to archive_folder
              logger.info("message# #{i+1} (#{message}) moved to archive")
            end
          rescue Exception => e
            logger.warn( "There was a problem moving message to archive : #{e.inspect}. #{e.backtrace.join("\n")}" )
          end
        end

        message_mails.size
      end
      
      
      
      
    end
  end
end