# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'serfx/version'

Gem::Specification.new do |spec|
  spec.name          = 'serfx'
  spec.version       = Serfx::VERSION
  spec.authors       = ['Rnjib Dey']
  spec.email         = ['dey.ranjib@gmail.com']
  spec.summary       = %q{A barebone ruby client for serf}
  spec.description   = %q{Serfx is a minimal ruby client for serf, an event based orchestration system}
  spec.homepage      = 'https://github.com/ranjib/serfx'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_dependency 'msgpack'
  spec.add_dependency 'mixlib-log'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'cucumber'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'redcarpet'
  spec.add_development_dependency 'yard'
end
