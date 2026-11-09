# Plain Ruby (no ActiveSupport), usable at Gemfile time and on Ruby 2.7.
require "rubygems"

module Lab
  class GemSource
    SOURCES = %w[local rubygems].freeze
    LOCAL_PATH = "/permittable".freeze

    attr_reader :source, :requested_version

    def self.from_env(env = ENV)
      source = env["PERMITTABLE_SOURCE"].to_s
      source = "local" if source.empty?
      version = env["PERMITTABLE_VERSION"].to_s
      version = nil if version.empty?

      unless SOURCES.include?(source)
        raise ArgumentError, "PERMITTABLE_SOURCE must be one of: #{SOURCES.join(', ')} (got #{source.inspect})"
      end
      if source == "local" && version
        raise ArgumentError, "PERMITTABLE_VERSION only applies when PERMITTABLE_SOURCE=rubygems (got #{version.inspect})"
      end
      if version && !(Gem::Version.correct?(version) && version.match?(/\A\d+(\.\w+)*\z/))
        raise ArgumentError, "PERMITTABLE_VERSION must be an exact version such as 0.12.0 (got #{version.inspect})"
      end

      new(source.to_sym, version)
    end

    def self.current
      @current ||= from_env(ENV)
    end

    def initialize(source, requested_version)
      @source = source
      @requested_version = requested_version
    end

    def gem_args
      return ["permittable", { path: LOCAL_PATH }] if source == :local
      requested_version ? ["permittable", "= #{requested_version}"] : ["permittable"]
    end

    def label(gem_version)
      detail =
        if source == :local then "local"
        elsif requested_version then "rubygems, pinned"
        else "rubygems, latest"
        end
      "permittable #{gem_version} (#{detail})"
    end

    def lock_key
      return "local" if source == :local
      "rubygems@#{requested_version || 'latest'}"
    end
  end
end
