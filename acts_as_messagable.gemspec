# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'acts_as_messagable/version'

Gem::Specification.new do |spec|
  spec.name          = "acts_as_messagable"
  spec.version       = ActsAsMessagable::VERSION
  spec.authors       = ["Stefan Exner"]
  spec.email         = ["stex@sterex.de"]
  spec.description   = %q{Handles Message sending between ActiveRecord instances}
  spec.summary       = %q{Handles Message sending between ActiveRecord instances}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'yard'
  spec.add_development_dependency 'redcarpet', '~> 2.3.0'
end
