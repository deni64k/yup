# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run 'rake gemspec'
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "yup"
  s.version = "0.2.2"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Denis Sukhonin"]
  s.date = "2013-02-18"
  s.description = "Just answers 200 (or specified) to a client and asynchronously forwards HTTP request to a configured host"
  s.email = "d.sukhonin@gmail.com"
  s.executables = ["yupd"]
  s.extra_rdoc_files = [
    "LICENSE.txt",
    "README.rdoc"
  ]
  s.files = [
    ".document",
    ".travis.yml",
    "Gemfile",
    "Gemfile.lock",
    "LICENSE.txt",
    "README.rdoc",
    "Rakefile",
    "VERSION",
    "bin/yupd",
    "lib/yup.rb",
    "lib/yup/request_forwarder.rb",
    "lib/yup/request_handler.rb",
    "lib/yup/state.rb",
    "lib/yup/state/bdb.rb",
    "lib/yup/state/redis.rb",
    "lib/yup/version.rb",
    "test/helper.rb",
    "test/test_stateful_yup_with_bdb.rb",
    "test/test_stateful_yup_with_redis.rb",
    "test/test_yup.rb",
    "yup.gemspec"
  ]
  s.homepage = "http://github.com/neglectedvalue/yup"
  s.licenses = ["MIT"]
  s.require_paths = ["lib"]
  s.rubygems_version = "1.8.24"
  s.summary = "HTTP forwarder"

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<eventmachine>, [">= 0"])
      s.add_runtime_dependency(%q<em-http-request>, [">= 0"])
      s.add_runtime_dependency(%q<http_parser.rb>, [">= 0"])
      s.add_runtime_dependency(%q<tuple>, [">= 0"])
      s.add_runtime_dependency(%q<yajl-ruby>, [">= 0"])
      s.add_development_dependency(%q<bdb>, [">= 0"])
      s.add_development_dependency(%q<redis-namespace>, [">= 0"])
      s.add_development_dependency(%q<yard>, ["~> 0.9.20"])
      s.add_development_dependency(%q<minitest>, ["~> 4.5"])
      s.add_development_dependency(%q<bundler>, ["~> 1.2"])
      s.add_development_dependency(%q<jeweler>, ["~> 1.8.4"])
      s.add_development_dependency(%q<simplecov>, ["~> 0.7.1"])
      s.add_development_dependency(%q<simplecov-rcov>, ["~> 0.2.3"])
      s.add_development_dependency(%q<travis-lint>, ["~> 1.4"])
    else
      s.add_dependency(%q<eventmachine>, [">= 0"])
      s.add_dependency(%q<em-http-request>, [">= 0"])
      s.add_dependency(%q<http_parser.rb>, [">= 0"])
      s.add_dependency(%q<tuple>, [">= 0"])
      s.add_dependency(%q<yajl-ruby>, [">= 0"])
      s.add_dependency(%q<bdb>, [">= 0"])
      s.add_dependency(%q<redis-namespace>, [">= 0"])
      s.add_dependency(%q<yard>, ["~> 0.9.20"])
      s.add_dependency(%q<minitest>, ["~> 4.5"])
      s.add_dependency(%q<bundler>, ["~> 1.2"])
      s.add_dependency(%q<jeweler>, ["~> 1.8.4"])
      s.add_dependency(%q<simplecov>, ["~> 0.7.1"])
      s.add_dependency(%q<simplecov-rcov>, ["~> 0.2.3"])
      s.add_dependency(%q<travis-lint>, ["~> 1.4"])
    end
  else
    s.add_dependency(%q<eventmachine>, [">= 0"])
    s.add_dependency(%q<em-http-request>, [">= 0"])
    s.add_dependency(%q<http_parser.rb>, [">= 0"])
    s.add_dependency(%q<tuple>, [">= 0"])
    s.add_dependency(%q<yajl-ruby>, [">= 0"])
    s.add_dependency(%q<bdb>, [">= 0"])
    s.add_dependency(%q<redis-namespace>, [">= 0"])
    s.add_dependency(%q<yard>, ["~> 0.9.20"])
    s.add_dependency(%q<minitest>, ["~> 4.5"])
    s.add_dependency(%q<bundler>, ["~> 1.2"])
    s.add_dependency(%q<jeweler>, ["~> 1.8.4"])
    s.add_dependency(%q<simplecov>, ["~> 0.7.1"])
    s.add_dependency(%q<simplecov-rcov>, ["~> 0.2.3"])
    s.add_dependency(%q<travis-lint>, ["~> 1.4"])
  end
end

