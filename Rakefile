require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "sonar_exchange_pull_connector"
    gem.summary = %Q{An Microsoft Exchange plugin for the Trampoline SONAR connector}
    gem.description = %Q{Plugin to pull email from an MS Exchange server and convert to JSON.}
    gem.email = "hello@empire42.com"
    gem.homepage = "http://github.com/trampoline/sonar-exchange-pull-connector"
    gem.authors = ["Peter MacRobert", "Mark Meyer"]
    
    gem.add_dependency "sonar_connector", ">= 0.7.2"
    gem.add_dependency "activesupport", "= 2.3.8"
    gem.add_dependency "json_pure", ">= 1.2.2"
    gem.add_dependency "sonar_rexchange", ">= 0.3.7"
    
    gem.add_development_dependency "rspec", ">= 1.2.9"
    gem.add_development_dependency "rr", ">= 0.10.5"
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end

require 'spec/rake/spectask'
Spec::Rake::SpecTask.new(:spec) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.spec_files = FileList['spec/**/*_spec.rb']
end

Spec::Rake::SpecTask.new(:rcov) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.pattern = 'spec/**/*_spec.rb'
  spec.rcov = true
end

task :default => :spec
task :spec => :check_dependencies
