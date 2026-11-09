module Lab
  # Keeps the suite honest: no way to skip, hold back or filter examples away.
  module Hygiene
    WORDS = %w[skip pending xit xdescribe xcontext xspecify fit fdescribe fcontext known_bug].freeze
    PATTERNS = (WORDS.map { |w| [/(?<![\w])#{w}(?![\w])/, w] } + [
      [/(?<![\w])focus:\s*true/, "focus: true"],
      [/RSpec::Core::Pending/, "RSpec::Core::Pending"]
    ]).freeze
    FILTER = [/(?<![\w])filter_run_excluding(?![\w])/, "filter_run_excluding"].freeze
    SYSTEM = [
      [/driver\.post/, "driver.post"], [/driver\.submit/, "driver.submit"], [/(?<![\w])fetch\(/, "fetch("],
      [/XMLHttpRequest/, "XMLHttpRequest"], [/requestSubmit/, "requestSubmit"], [/\.submit\(/, ".submit("]
    ].freeze

    def self.violations(source, path)
      patterns = PATTERNS.dup
      normalized = path.to_s.tr("\\", "/")
      allowed_filter = normalized.include?("shared/lib/lab") || File.basename(normalized) == "spec_helper.rb"
      patterns << FILTER unless allowed_filter
      patterns.concat(SYSTEM) if normalized.include?("shared/spec/system/")

      out = []
      source.to_s.each_line.with_index(1) do |line, n|
        code = code_part(line)
        patterns.each do |re, label|
          out << "#{path}:#{n}: banned #{label.inspect}: #{line.strip}" if code.match?(re)
        end
      end
      out
    end

    # Blank out string literals, then drop everything after a comment marker.
    def self.code_part(line)
      line = line.gsub(/"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'/) { |m| '"' + " " * (m.size - 2) + '"' }
      line.sub(/#.*\z/m, "")
    end
  end
end
