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
      attr_reader :xml_href_regex
      attr_reader :retrieve_batch_size
      
      attr_reader :working_dir
      attr_reader :complete_dir
      
      def parse(settings)
        
        @working_dir = File.join(connector_dir, 'working')
        @complete_dir = File.join(connector_dir, 'complete')
        
        # validate that the important params are present
        ["dav_uri", "owa_uri", "username", "mailbox"].each {|param|
          raise Sonar::Connector::InvalidConfig.new("Connector #{self.name}: parameter '#{param}' cannot be blank.") if settings[param].blank?
        }
        
        @dav_uri = settings["dav_uri"]
        @owa_uri = settings["owa_uri"]
        @username = settings["username"]
        @password = settings["password"]
        @mailbox = settings["mailbox"]
        @retrieve_batch_size = settings["retrieve_batch_size"] || 1000
        @delete_processed_messages = settings["delete_processed_messages"] == true
        @is_journal_account = settings["is_journal_account"] == true
        @xml_href_regex = !settings["xml_href_regex"].blank? ? Regexp.new(settings["xml_href_regex"]) : /<.*?a:propstat.*?>.*?<.*?a:status.*?>.*?HTTP\/1\.1.*?200.*?OK.*?<.*?a:href.*?>(.*?)<\/.*?a:href.*?>.*?\/a:propstat.*?>/im
      end
      
      def action
        
        # setup folders and cleanup old working dirs
        create_dirs
        cleanup_working_dir
        current_working_dir = create_timestamped_working_dir
        
        # create Exchange connection and try to connect
        begin
          session = Sonar::Connector::ExchangeSession.new(:owa_uri=>owa_uri, :dav_uri=>dav_uri, :username=>username, :password=>password, :log=>log)
          session.open_session
          session.test_connection
          state[:consecutive_connection_failures] = 0
        rescue RExchange::RException
          
          state[:consecutive_connection_failures] ? state[:consecutive_connection_failures] + 1 : 1
          
          # Send admin email if the count hits 5
          if state[:consecutive_connection_failures] == 5
            queue << Sonar::Connector::SendAdminEmailCommand.new(self, "tried 5 times and failed to connect to the Exchange Server")
            state[:consecutive_connection_failures] = 0
          end
          return
        end
        
        # get messages and save each one to disk in json format
        session.get_messages(
          :folder=>session.root_folder.inbox, 
          :archive_folder=>session.root_folder.inbox.archive,
          :batch_limit=>retrieve_batch_size,
          :href_regex=>xml_href_regex
        ){ |mail|
          json_content = create_json mail
          write_to_file json_content, current_working_dir
          archive_or_delete mail
        }
        
        FileUtils.mv(current_working_dir, complete_dir)
        update_statistics
      end
      
      private
      
      def create_dirs
        FileUtils.mkdir_p working_dir unless File.directory?(working_dir)
        FileUtils.mkdir_p complete_dir unless File.directory?(complete_dir)
      end
      
      def create_timestamped_working_dir
        t = Time.now
        dir = File.join(working_dir, "working_#{t.to_i * 1000000 + t.usec}")
        FileUtils.mkdir_p dir
        log.info("created current working dir '#{dir}'")
        dir
      end
      
      def cleanup_working_dir
        Dir[File.join working_dir, "*"].each{|dir|
          next unless File.directory?(dir)
          
          # Remove empty directories
          if Dir[File.join dir, "*"].empty?
            FileUtils.rmdir(dir)
            log.info "Removed empty dir: #{dir}"
            
          else # move non-empty dirs to complete dir
            FileUtils.mv dir, complete_dir
            log.info "Moved dir #{dir} to complete dir."
          end
        }
      end
      
      def move_to_complete_dir(dir)
      end
      
      # schedule the update of key statistics in the stats.yml file
      def update_statistics
      end
      
      def create_json(mail)
        {"foo"=>"bar"}.to_json
      end
      
      def write_to_file(content, dir)
      end
      
      def archive_or_delete(mail)
      end
      
    end
  end
end