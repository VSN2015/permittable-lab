require "uri"
require "securerandom"

module Inspector
  # Rack middleware. Sits outside ShowExceptions so it sees the final response.
  # The response goes through untouched; only a copy is kept for the panel.
  class Middleware
    SKIP_PREFIX = "/inspector".freeze
    FORM_TYPE = "application/x-www-form-urlencoded".freeze

    # Replays the buffered chunks and closes the original body.
    class Replay
      def initialize(chunks, original)
        @chunks = chunks
        @original = original
      end

      def each(&block)
        @chunks.each(&block)
      end

      def close
        @original.close if @original.respond_to?(:close)
      end
    end

    def initialize(app)
      @app = app
    end

    def call(env)
      return @app.call(env) if env["PATH_INFO"].to_s.start_with?(SKIP_PREFIX)

      entry = Entry.new(
        request_id: env["action_dispatch.request_id"] || SecureRandom.uuid,
        method: env["REQUEST_METHOD"], path: env["PATH_INFO"].to_s,
        raw_params: read_raw_params(env), rejected: false, violations: [],
        log_lines: [], events: [], config: { error_format: Permittable.error_format, mode: Permittable.mode }
      )
      Current.entry = entry
      begin
        status, headers, body = @app.call(env)
      rescue Exception => e # rubocop:disable Lint/RescueException
        entry.status = 500
        entry.response_body = Inspector.clip("#{e.class}: #{e.message}", BODY_LIMIT)
        Store.record(entry)
        raise
      ensure
        Current.entry = nil
      end
      capture(entry, status, headers, body)
    end

    private

    def capture(entry, status, headers, body)
      entry.status = status
      entry.content_type = header(headers, "content-type")
      unless bufferable?(headers, body)
        entry.response_body = "(not captured: streamed response)"
        Store.record(entry)
        return [status, headers, body]
      end

      chunks = []
      body.each { |chunk| chunks << chunk.dup }
      text = chunks.join.force_encoding(Encoding::UTF_8)
      text = text.scrub("?") unless text.valid_encoding?
      entry.response_body = Inspector.clip(text, BODY_LIMIT)
      Store.record(entry)
      [status, headers, Replay.new(chunks, body)]
    end

    def bufferable?(headers, body)
      return false if header(headers, "content-type").to_s.start_with?("text/event-stream")
      return false if headers.respond_to?(:key?) && headers.key?("rack.hijack")
      return false unless body.respond_to?(:each)
      return false if body.respond_to?(:to_path)

      true
    end

    def header(headers, name)
      headers[name] || headers[name.split("-").map(&:capitalize).join("-")]
    end

    def read_raw_params(env)
      pairs = decode(env["QUERY_STRING"].to_s)
      input = env["rack.input"]
      if input && input.respond_to?(:rewind) && env["CONTENT_LENGTH"].to_s != "0"
        # An earlier middleware (MethodOverride) may have read the body and left
        # the position at the end, so rewind first; leave it rewound for the app.
        input.rewind
        body = input.read.to_s
        input.rewind
        unless body.empty?
          if env["CONTENT_TYPE"].to_s.start_with?(FORM_TYPE)
            pairs.concat(decode(body))
          else
            pairs << ["(body)", body.dup.force_encoding(Encoding::UTF_8).scrub("?")]
          end
        end
      end
      pairs
    rescue StandardError => e
      [["(unparseable)", e.message.to_s.scrub("?")]]
    end

    # URI.decode_www_form replaces invalid bytes with U+FFFD, which would hide them,
    # so the unescaped bytes are checked first.
    def decode(string)
      unescaped = string.b.tr("+", " ").gsub(/%\h\h/n) { |m| m[1, 2].hex.chr }
      raise ArgumentError, "invalid UTF-8 in parameters" unless unescaped.force_encoding(Encoding::UTF_8).valid_encoding?

      URI.decode_www_form(string)
    end
  end
end
