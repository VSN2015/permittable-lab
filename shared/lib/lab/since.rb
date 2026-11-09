require "rubygems"
require_relative "gem_source"

module Lab
  module Since
    def self.applies?(since, source: Lab::GemSource.current, gem_version: Permittable::VERSION)
      return true if since.nil?
      unless Gem::Version.correct?(since.to_s) && since.to_s.match?(/\A\d+(\.\w+)*\z/)
        raise ArgumentError, "malformed since: #{since.inspect}"
      end
      return true if source.source == :local
      Gem::Version.new(gem_version) >= Gem::Version.new(since.to_s)
    end
  end
end
