# Host-side (Ruby 2.7+, stdlib only): turns per-version report JSON into a table.
module Lab
  module MatrixReport
    Row = Struct.new(:version, :rails, :ruby, :gem_label, :green, :red, :not_applicable,
                     :status, :failed, :na_list, :log_path)

    HEADER = %w[Rails Ruby Gem Green Red N/A Result].freeze

    def self.row(version:, report:, exit_status:, log_path: nil)
      return Row.new(version, version, "-", "-", 0, 0, 0, :failed_to_run, [], [], log_path) if report.nil?

      failures = report["failures"].to_i
      held = report["pending"].to_i
      outside = report["errors_outside_examples"].to_i
      examples = report["examples"].to_i
      na = report["not_applicable"] || []
      red = failures + held + outside

      status =
        if examples.zero? then :failed_to_run
        elsif red.zero? && exit_status != 0 then :failed_to_run
        elsif red.positive? then :red
        else :pass
        end

      Row.new(version, report["rails_version"] || version, report["ruby_version"] || "-",
              gem_label(report["gem"]), report["green"].to_i, red, na.size, status,
              (report["failed"] || []).map { |f| f["location"] }, na, log_path)
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
        block << "  no report found; see #{r.log_path}" if r.status == :failed_to_run && r.log_path
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
