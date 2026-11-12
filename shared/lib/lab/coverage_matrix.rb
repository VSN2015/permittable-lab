# Stdlib only, Ruby 2.7 compatible: bin/coverage-report runs on the host's Ruby.
require "yaml"
require "ripper"

module Lab
  # docs/coverage-matrix.yml ties each README/CHANGELOG feature to the spec that tests it.
  module CoverageMatrix
    UNCOVERED = "chưa phủ".freeze
    AWAITING = "chờ tác giả".freeze
    OUT_OF_SCOPE = "ngoài phạm vi".freeze
    OUT_AREA = "out-of-scope".freeze
    AREAS = %w[
      out-of-scope declaring field-kind field-option preset type absence error i18n problem
      unknown-params reuse reshape drift logging events monitor rake beyond-controller config
      classload changelog
    ].freeze
    PLANS = (1..6).freeze
    COVERS = /covers:\s*(?:%[wi]\[([^\]]*)\]|\[([^\]]*)\])/.freeze

    def self.load(path)
      data = YAML.safe_load(File.read(path, encoding: "UTF-8"))
      raise ArgumentError, "#{path}: expected a YAML list of rows" unless data.is_a?(Array)

      data
    end

    # Ids a spec file declares with covers: %w[...] (or a quoted array).
    def self.covers_in(source)
      code = Ripper.lex(source).reject { |t| t[1] == :on_comment || t[1].to_s.start_with?("on_embdoc") }.map { |t| t[2] }.join
      code.scan(COVERS).flat_map do |words, quoted|
        words ? words.split : quoted.to_s.scan(/["']([^"']+)["']|:([\w-]+)/).map { |a, b| a || b }
      end
    end

    def self.path_status?(status)
      status.is_a?(String) && status.end_with?("_spec.rb")
    end

    def self.problems(rows, spec_root:, spec_files:)
      out = []
      ids = rows.map { |r| r["id"] }
      ids.select { |id| ids.count(id) > 1 }.uniq.each { |id| out << "#{id}: duplicate id" }

      rows.each { |row| out.concat(row_problems(row, spec_root)) }

      known = ids.compact
      spec_files.each do |file|
        covers_in(File.read(file, encoding: "UTF-8")).each do |id|
          out << "#{id}: orphan, #{file} declares covers: #{id} but no matrix row has that id" unless known.include?(id)
        end
      end
      out
    end

    def self.row_problems(row, spec_root)
      id = row["id"]
      label = id.to_s
      out = []
      out << "#{label}: id must be kebab-case" unless id.is_a?(String) && id.match?(/\A[a-z0-9]+(-[a-z0-9_]+)*\z/)
      out << "#{label}: unknown area #{row['area'].inspect}" unless AREAS.include?(row["area"])
      %w[feature readme].each { |k| out << "#{label}: #{k} is required" if row[k].to_s.strip.empty? }

      since = row["since"]
      out << "#{label}: since #{since.inspect} is not a version string" unless since.is_a?(String) && Gem::Version.correct?(since)

      status = row["status"]
      plan = row["plan"]
      if plan.nil?
        out << "#{label}: plan is required unless status is #{OUT_OF_SCOPE}" unless status == OUT_OF_SCOPE
      elsif !PLANS.cover?(plan) || !plan.is_a?(Integer)
        out << "#{label}: plan #{plan.inspect} is not in 1..6"
      end

      if status == UNCOVERED
        nil
      elsif status == AWAITING
        out << "#{label}: status #{AWAITING} needs a question" if row["question"].to_s.strip.empty?
      elsif status == OUT_OF_SCOPE
        out << "#{label}: status #{OUT_OF_SCOPE} needs a reason" if row["reason"].to_s.strip.empty?
        out << "#{label}: status #{OUT_OF_SCOPE} needs area #{OUT_AREA}" unless row["area"] == OUT_AREA
      elsif path_status?(status)
        out.concat(path_problems(label, status, spec_root, covering: true))
      else
        out << "#{label}: status #{status.inspect} is not a spec path, #{UNCOVERED.inspect}, #{AWAITING.inspect} or #{OUT_OF_SCOPE.inspect}"
      end

      Array(row["also"]).each do |path|
        out.concat(path_problems(label, path, spec_root, covering: true))
      end
      out
    end

    def self.path_problems(label, path, spec_root, covering:)
      full = File.join(spec_root, path.to_s)
      return ["#{label}: spec file #{path} does not exist"] unless File.file?(full)
      return [] unless covering
      return [] if covers_in(File.read(full, encoding: "UTF-8")).include?(label)

      ["#{label}: #{path} has no covers: entry for #{label}"]
    end

    def self.summary(rows)
      counts = { covered: 0, uncovered: 0, awaiting_author: 0, out_of_scope: 0 }
      rows.each do |row|
        case row["status"]
        when UNCOVERED then counts[:uncovered] += 1
        when AWAITING then counts[:awaiting_author] += 1
        when OUT_OF_SCOPE then counts[:out_of_scope] += 1
        else counts[:covered] += 1
        end
      end
      { total: rows.size }.merge(counts)
    end
  end
end
