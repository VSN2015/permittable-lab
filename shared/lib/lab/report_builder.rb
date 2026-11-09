module Lab
  module ReportBuilder
    def self.build(rails_version:, ruby_version:, gem_source:, gem_version:, requested_version:,
                   examples:, not_applicable:, errors_outside_examples:)
      failed = examples.select { |e| e[:status] == :failed }
      held = examples.count { |e| e[:status] == :pending }
      {
        rails_version: rails_version,
        ruby_version: ruby_version,
        gem: { source: gem_source, requested_version: requested_version, version: gem_version },
        examples: examples.size,
        green: examples.size - failed.size - held,
        failures: failed.size,
        pending: held,
        errors_outside_examples: errors_outside_examples,
        failed: failed.map { |e| { location: e[:location], description: e[:description] } },
        not_applicable: not_applicable
      }
    end
  end
end
