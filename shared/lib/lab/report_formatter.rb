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
      write_report(notification, source: Lab::GemSource.current, gem_version: Permittable::VERSION,
                                 world_examples: RSpec.world.all_examples, path: Rails.root.join("tmp", "lab-report.json"))
    end

    def write_report(notification, source:, gem_version:, world_examples:, path:)
      examples = notification.examples.map do |e|
        { description: e.full_description, location: e.location, status: e.execution_result.status,
          since: e.metadata[:since] }
      end
      not_applicable = world_examples.reject do |e|
        Lab::Since.applies?(e.metadata[:since], source: source, gem_version: gem_version)
      end.map do |e|
        { description: e.full_description, location: e.location, since: e.metadata[:since] }
      end

      report = Lab::ReportBuilder.build(
        rails_version: Rails.version, ruby_version: RUBY_VERSION,
        gem_source: source.source, gem_version: gem_version,
        requested_version: source.requested_version,
        examples: examples, not_applicable: not_applicable,
        errors_outside_examples: notification.errors_outside_of_examples_count
      )
      path = Pathname.new(path.to_s)
      FileUtils.mkdir_p(path.dirname)
      File.write(path, JSON.pretty_generate(report))

      return if not_applicable.empty?
      @output.puts "#{not_applicable.size} cases not applicable to permittable #{gem_version}:"
      not_applicable.each { |c| @output.puts "  #{c[:location]} (since #{c[:since]}) #{c[:description]}" }
    end
  end
end
