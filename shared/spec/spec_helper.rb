$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "lab/gem_source"
require "lab/since"
require "lab/report_builder"
require "lab/report_formatter"
require "lab/hygiene"

ENV["RAILS_ENV"] ||= "test"
require File.expand_path("config/environment", Dir.pwd)
require "rspec/rails"

puts Lab::GemSource.current.label(Permittable::VERSION)
puts "Rails #{Rails.version}"
puts "ruby #{RUBY_VERSION}"

RSpec.configure do |config|
  config.infer_spec_type_from_file_location!
  config.filter_run_excluding since: ->(v) { !Lab::Since.applies?(v) }
  config.expect_with(:rspec) { |c| c.syntax = :expect }
end
