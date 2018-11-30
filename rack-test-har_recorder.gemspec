# coding: utf-8
root = "."

Gem::Specification.new do |spec|
  spec.name          = "rack-test-har_recorder"
  spec.version       = '1.0.0'
  spec.authors       = ["Cvent"]
  spec.email         = ["dvogel@cvent.com"]
  spec.summary       = %q{Records HTTP requests and responses inside your test suite.}
  spec.description   = %q{Records HTTP requests and responses inside your test suite. Useful for debugging and documenting APIs.}
  spec.homepage      = "https://github.com/cvent/rack-test-har_recorder"
  spec.license       = "Apache-2.0"

  spec.files         = `git ls-files -z #{root}`.split("\x0")
  spec.executables   = spec.files.grep(%r{^#{root}/bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^#{root}/(test|spec|features)/})
  spec.require_paths = ["#{root}/lib"]

  spec.add_dependency "addressable", '~> 2.3'
  spec.add_dependency "rack-test", '>= 0.6.3'
  spec.add_dependency "json", '~> 2.0'

  spec.add_development_dependency "bundler", "~> 1.8"
  spec.add_development_dependency "pry", "~> 0.10"
  spec.add_development_dependency "pry-nav", "~> 0.2"
  spec.add_development_dependency "rspec", "~> 3.7"
  spec.add_development_dependency "rspec-collection_matchers", "~> 1.1"
  spec.add_development_dependency "simplecov", "~> 0.16"
end

