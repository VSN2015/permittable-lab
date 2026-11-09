require "json"
require "fileutils"
require "rspec/core"
require_relative "gem_source"
require_relative "since"
require_relative "report_builder"

module Lab
  class ReportFormatter
    RSpec::Core::Formatters.register self, :dump_summary

    def initialize(output)
      @output = output
    end

    def dump_summary(notification)
      source = Lab::GemSource.current
      examples = notification.examples.map do |e|
        { description: e.full_description, location: e.location, status: e.execution_result.status,
          since: e.metadata[:since] }
      end
      not_applicable = RSpec.world.all_examples.reject { |e| Lab::Since.applies?(e.metadata[:since]) }.map do |e|
        { description: e.full_description, location: e.location, since: e.metadata[:since] }
      end

      report = Lab::ReportBuilder.build(
        rails_version: Rails.version, ruby_version: RUBY_VERSION,
        gem_source: source.source, gem_version: Permittable::VERSION,
        requested_version: source.requested_version,
        examples: examples, not_applicable: not_applicable,
        errors_outside_examples: notification.errors_outside_of_examples_count
      )
      path = Rails.root.join("tmp", "lab-report.json")
      FileUtils.mkdir_p(path.dirname)
      File.write(path, JSON.pretty_generate(report))

      return if not_applicable.empty?
      @output.puts "#{not_applicable.size} cases not applicable to permittable #{Permittable::VERSION}:"
      not_applicable.each { |c| @output.puts "  #{c[:location]} (since #{c[:since]}) #{c[:description]}" }
    end
  end
end
