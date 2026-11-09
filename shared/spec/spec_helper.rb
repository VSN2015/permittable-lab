$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "lab/gem_source"

ENV["RAILS_ENV"] ||= "test"
require File.expand_path("config/environment", Dir.pwd)
require "rspec/rails"

RSpec.configure do |config|
  config.infer_spec_type_from_file_location!
  config.filter_run_when_matching :focus
  config.expect_with(:rspec) { |c| c.syntax = :expect }
end
