module Lab
  # Keeps the suite honest: no way to skip, hold back or filter examples away.
  module Hygiene
    WORDS = %w[skip pending xit xdescribe xcontext xspecify xexample fit fdescribe fcontext fspecify fexample focus known_bug].freeze
    PATTERNS = (WORDS.map { |w| [/(?<![\w])#{w}(?![\w])/, w] } + [
      [/(?<![\w])focus:\s*true/, "focus: true"],
      [/RSpec::Core::Pending/, "RSpec::Core::Pending"]
    ]).freeze
    FILTER_WORDS = %w[filter_run_excluding filter_run_when_matching filter_run_including filter_run exclusion_filter].freeze
    FILTERS = FILTER_WORDS.map { |w| [/(?<![\w])#{w}(?![\w])/, w] }.freeze
    ALLOWED_FILTER_FILES = %w[shared/spec/spec_helper.rb].freeze
    SYSTEM = [
      [/driver\.post/, "driver.post"], [/driver\.submit/, "driver.submit"], [/(?<![\w])fetch\(/, "fetch("],
      [/XMLHttpRequest/, "XMLHttpRequest"], [/requestSubmit/, "requestSubmit"], [/\.submit\(/, ".submit("]
    ].freeze

    def self.violations(source, path)
      patterns = PATTERNS.dup
      normalized = path.to_s.tr("\\", "/")
      allowed_filter = normalized.include?("shared/lib/lab/") ||
        ALLOWED_FILTER_FILES.any? { |f| normalized == f || normalized.end_with?("/" + f) }
      patterns.concat(FILTERS) unless allowed_filter
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
      # Quoted-symbol metadata would be erased by blanking, so make it bare first.
      line = line.gsub(/"(skip|pending|focus)":/, '\1:').gsub(/:"(skip|pending|focus)"/, ':\1')
      line = line.gsub(/"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'/) { |m| '"' + " " * (m.size - 2) + '"' }
      line.sub(/#.*\z/m, "")
    end
  end
end
