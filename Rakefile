require 'rubygems'
require 'rubygems/package_task'

require 'lib/version'
gemspec = Gem::Specification.new do |s|
  s.name         = "morpheus"
  s.version      = Morpheus::VERSION
  s.authors      = ["David Mike Simon"]
  s.email        = "david.mike.simon@gmail.com"
  s.homepage     = "http://github.com/DavidMikeSimon/morpheus"
  s.summary      = "Rails and XSLT, together at last"
  s.description  = "No, really, this lets you use XSLT in Rails. Don't laugh, it can sometimes be a good idea! Occasionally."
  s.files        = `git ls-files .`.split("\n") - [".gitignore"]
  s.platform     = Gem::Platform::RUBY
  s.require_path = 'lib'
  s.rubyforge_project = '[none]'

  s.add_dependency('actionpack')
  s.add_dependency('nokogiri')
end

Gem::PackageTask.new(gemspec) do |pkg|
end
