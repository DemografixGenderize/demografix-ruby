# frozen_string_literal: true

require_relative "lib/demografix/version"

Gem::Specification.new do |spec|
  spec.name = "demografix"
  spec.version = Demografix::VERSION
  spec.authors = ["Demografix"]
  spec.email = ["info@genderize.io"]

  spec.summary = "Official Ruby client for the genderize, agify, and nationalize APIs."
  spec.description = "One client for the three Demografix APIs — gender, age, and " \
                     "nationality prediction from names — reporting the remaining " \
                     "quota carried on every response."
  spec.homepage = "https://github.com/DemografixGenderize/demografix-ruby"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["documentation_uri"] = "https://genderize.io/documentation/api"
  spec.metadata["source_code_uri"] = "https://github.com/DemografixGenderize/demografix-ruby"
  spec.metadata["bug_tracker_uri"] = "https://github.com/DemografixGenderize/demografix-ruby/issues"

  spec.files = Dir["lib/**/*.rb", "README.md", "LICENSE"]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "webmock", "~> 3.18"
end
