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
        
        create_dirs
        current_working_dir = create_timestamped_working_dir working_dir
        
        # pseudocode
        cleanup_working_dir
        connect_to_exchange(connect_params)
        
        get_batch_of_mail(folder_params).each do |mail|
          save_json_to_file_in_working_dir (mail.to_json)
          archive_or_delete mail
        end
        
        move_working_dir_to_complete_dir
        update_statistics
      end
      
      private
      
      def make_dirs
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
      
      
    end
  end
end
