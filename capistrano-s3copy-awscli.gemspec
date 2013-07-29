# coding: utf-8
#lib = File.expand_path('../lib', __FILE__)
#$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require File.expand_path('../lib/capistrano-s3copy-awscli/version', __FILE__)

Gem::Specification.new do |gem|
  gem.name          = "capistrano-s3copy-awscli"
  gem.version       = Capistrano::S3copy::Awscli::VERSION
  gem.authors       = ["Takayuki Okawa"]
  gem.email         = ["takayuki.ohkawa@gmail.com"]
  gem.description   = %q{Capistrano deployment strategy that creates and pushes a tarball
into S3, for both pushed deployments and pulled auto-scaling.
Modified to use aws-cli(https://github.com/aws/aws-cli) from s3cmd.
The original source is Capistrano-S3-Copy(http://github.com/richie/capistrano-s3-copy)}
  gem.summary       = %q{Capistrano deployment strategy that transfers the release on S3}
  gem.homepage      = "https://github.com/bacter1a/capistrano-s3copy-awscli.git"
  gem.license       = "MIT"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}) { |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  #gem.add_development_dependency "bundler", "~> 1.3"
  #gem.add_development_dependency "rake"
  gem.add_dependency 'capistrano', ">= 2.12.0"
end
