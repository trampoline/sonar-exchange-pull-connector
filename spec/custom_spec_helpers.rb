module CustomSpecHelpers
  
  def load_fixture_file(relative_filename)
    complete_file = File.join File.dirname(__FILE__), "fixtures", relative_filename
    File.read complete_file
  end
  
  def integration_connection_settings(version='2007')
    case version
    when '2007'
      {
        'dav_uri'  => 'https://exchangevm/Exchange/',
        'auth_type'=> 'basic',
        # must be provided for form-based authentication
        # 'owa_uri'  => 'https://exchangevm/owa/auth/owaauth.dll',
        'username' => 'journal',
        'password' => 'D33pfried',
        'mailbox'  => 'journal@trampolan.local',
        'delete_processed_messages' => '0',
        'is_journal_account' => '0'
      }
    when '2003'
      {
        'dav_uri'  => 'http://sbs2003vm/exchange/',
        'auth_type'=> 'basic',
        # must be provided for form-based authentication
        # 'owa_uri'  => 'http://sbs2003vm/exchweb/bin/auth/owaauth.dll',
        'username' => 'journal',
        'password' => 'h0spital50a',
        'mailbox'  => 'journal@trampolan1',
        'delete_processed_messages' => '0',
        'is_journal_account' => '0'
      }
    else
      raise ArgumentError.new("unknown Exchange version: #{version}")
    end
  end
  
  def stub_message(raw="RFC822 content")
    message = Object.new
    message.instance_eval do
      def <=>(other)
        self.object_id <=> other.object_id
      end
    end
        
    stub(message).to_s{"raw: #{raw}"}
    stub(message).raw{raw}
    message
  end
  
  def stub_folder(name="folder", messages=[], folders=[])
    folder = Object.new
    stub(folder).to_s{name}
    stub(folder).message_hrefs(is_a(Regexp)){messages}
    stub(folder).folders{folders}
    folder
  end
  
  def stub_rexception
    req = Hash.new
    stub(req).inspect{"request"}
    stub(req).body{"body"}
    stub(req).path{"path"}
    
    res = Hash.new
    
    RExchange::RException.new(req, res, Exception.new)
  end
  
end