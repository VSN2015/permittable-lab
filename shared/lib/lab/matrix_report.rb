# Host-side (Ruby 2.7+, stdlib only): turns per-version report JSON into a table.
module Lab
  module MatrixReport
    Row = Struct.new(:version, :rails, :ruby, :gem_label, :green, :red, :not_applicable,
                     :status, :failed, :na_list, :log_path, :reason, :held, :outside, :filtered)

    HEADER = %w[Rails Ruby Gem Green Red N/A Result].freeze

    def self.row(version:, report:, exit_status:, log_path: nil)
      return Row.new(version, version, "-", "-", 0, 0, 0, :failed_to_run, [], [], log_path, "no report", 0, 0, []) if report.nil?

      unless report["rails_version"].to_s.start_with?("#{version}.")
        return Row.new(version, report["rails_version"] || version, report["ruby_version"] || "-", gem_label(report["gem"]),
                       0, 0, 0, :failed_to_run, [], [], log_path,
                       "report is Rails #{report['rails_version'] || 'unknown'}, expected #{version}", 0, 0, [])
      end

      failures = report["failures"].to_i
      held = report["pending"].to_i
      outside = report["errors_outside_examples"].to_i
      examples = report["examples"].to_i
      na = report["not_applicable"] || []
      filtered = report["filtered_out"] || []
      red = failures + held + outside + filtered.size

      status, reason =
        if examples.zero? then [:failed_to_run, "nothing ran (0 examples)"]
        elsif red.zero? && exit_status != 0 then [:failed_to_run, "exit #{exit_status} disagrees with report"]
        elsif red.positive? then [:red, nil]
        else [:pass, nil]
        end

      Row.new(version, report["rails_version"] || version, report["ruby_version"] || "-",
              gem_label(report["gem"]), report["green"].to_i, red, na.size, status,
              (report["failed"] || []).map { |f| f["location"] }, na, log_path, reason, held, outside, filtered)
    end

    def self.gem_label(gem)
      return "-" unless gem
      detail =
        if gem["source"].to_s == "local" then "local"
        elsif gem["requested_version"] then "rubygems, pinned"
        else "rubygems, latest"
        end
      "permittable #{gem['version']} (#{detail})"
    end

    def self.result_text(row)
      case row.status
      when :pass then "PASS"
      when :red then "RED"
      else "FAILED TO RUN"
      end
    end

    def self.render(rows)
      cells = rows.map do |r|
        [r.rails.to_s, r.ruby.to_s, r.gem_label.to_s, r.green.to_s, r.red.to_s, r.not_applicable.to_s, result_text(r)]
      end
      line = ->(c) { c.join(" | ") }
      out = [line.call(HEADER), "-" * line.call(HEADER).length]
      cells.each { |c| out << line.call(c) }

      rows.each do |r|
        block = []
        r.failed.each { |loc| block << "  failed: #{loc}" }
        unless r.na_list.empty?
          block << "  #{r.na_list.size} cases not applicable to #{na_gem(r)}:"
          r.na_list.each { |c| block << "    #{c['location']} (since #{c['since']}) #{c['description']}" }
        end
        block << "  pending: #{r.held}" if r.held.to_i.positive?
        block << "  errors outside examples: #{r.outside}" if r.outside.to_i.positive?
        unless r.filtered.empty?
          block << "  filtered out: #{r.filtered.size} declared examples never ran (if:/unless:, --tag or another filter):"
          r.filtered.each { |c| block << "    #{c['location']} #{c['description']}" }
        end
        block << "  #{r.reason}" if r.status == :failed_to_run
        block << "  log: #{r.log_path}" if r.status != :pass && r.log_path
        next if block.empty?
        out << ""
        out << "Rails #{r.version}:"
        out.concat(block)
      end
      out.join("\n") + "\n"
    end

    def self.na_gem(row)
      row.gem_label.to_s.sub(/ \(.*\)\z/, "")
    end

    def self.exit_code(rows)
      rows.all? { |r| r.status == :pass } ? 0 : 1
    end
  end
end
