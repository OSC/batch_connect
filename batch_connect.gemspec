# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'batch_connect/version'

Gem::Specification.new do |spec|
  spec.name          = "batch_connect"
  spec.version       = BatchConnect::VERSION
  spec.authors       = ["Jeremy Nicklas"]
  spec.email         = ["jnicklas@osc.edu"]
  spec.summary       = %q{Generates batch scripts allowing users to connect to a server on an HPC resource.}
  spec.description   = %q{Library used to generate batch scripts that start up web servers, VNC servers, and etc., through batch jobs running on HPC resources. It is also used to generate connection information from these batch jobs so that a user can connect to their batch job server.}

  spec.homepage      = "https://github.com/OSC/batch_connect"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "mustache", "~> 1.0"
  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
end
