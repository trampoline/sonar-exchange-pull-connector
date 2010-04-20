$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'rubygems'
require 'spec'
require 'spec/autorun'
require 'rr'
require 'sonar_exchange_pull_connector'
require 'sonar_connector/rspec/spec_helper'

require 'custom_spec_helpers'
Spec::Example::ExampleMethods.send(:include, CustomSpecHelpers)