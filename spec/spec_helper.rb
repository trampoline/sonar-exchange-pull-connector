$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'rubygems'
require 'sonar_exchange_pull_connector'

require 'spec'
require 'spec/autorun'
require 'rr'

require 'sonar_connector/rspec/spec_helper'

def exchange_connection_settings(version='2007')
  case version
  when '2007'
    {
      'dav_uri'  => 'https://exchangevm/Exchange/',
      #must be provided for form-based authentication
      'owa_uri'  => 'https://exchangevm/owa/auth/owaauth.dll',
      'username' => 'journal',
      'password' => 'D33pfried',
      'mailbox'  => 'journal@trampolan.local',
      'delete_processed_messages' => '0',
      'is_journal_account' => '0'
    }
  when '2003'
    {
      'dav_uri'  => 'http://sbs2003vm/exchange/',
      #must be provided for form-based authentication
      'owa_uri'  => 'http://sbs2003vm/exchweb/bin/auth/owaauth.dll',
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