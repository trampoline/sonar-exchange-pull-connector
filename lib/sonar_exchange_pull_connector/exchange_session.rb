module Sonar
  module Connector
    
    # Represents a connection to an Exchange server. Most of this code is imported from the 
    # Trampoline Sonar codebase, particularly files:
    #   sonar-web/lib/exchange_connector.rb
    #   sonar-web/app/commands/connectors/exchange_retrieve_command.rb
    #   sonar-web/app/commands/import/extract_attachments_from_rfc822_command.rb 
    
    class ExchangeSession
      
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

      def schedule_import_command( dir, journal_account_output_dir, is_journal_account = false )
        # Exchange Journalling is a standard way of keepipng a copy of every mail that passes through
        # an Exchange server. BUT - it results in a NEW mail which contains the original mail as an 
        # attachment. So if it's a journal account, we don't want to import the raw rfc822, we actually need to 
        # unbundle the attachments and import them, discarding the outer message. 
        if is_journal_account.to_s == "1" # <= yes, i know. blame gunboat.
          logger.info( "scheduling an ExtractAttachmentsFromRfc822DirectoryCommand on #{dir} to output attachments to #{journal_account_output_dir}")
          ExtractAttachmentsFromRfc822DirectoryCommand.schedule!( 'dir'=> dir, 'output_dir' => journal_account_output_dir )
        else
          logger.info( "scheduling an ImportEmailDirectoryCommand on #{dir}")
          ImportEmailDirectoryCommand.schedule!( "dir"=>dir )
        end
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
      
      
    end
  end
end