require "logger"

module Inspector
  # A logger that copies each line into the current request's buffer and
  # writes nowhere else. Attached beside the real logger with broadcast_to.
  module LogTap
    class Device
      def write(message)
        entry = Current.entry
        entry.log_lines << message.to_s.chomp if entry
      end

      def close; end
    end

    module_function

    def build
      logger = ActiveSupport::Logger.new(Device.new)
      logger.level = Logger::DEBUG
      logger.formatter = ActiveSupport::Logger::SimpleFormatter.new
      logger
    end

    def attach(logger = Rails.logger)
      return false unless logger.respond_to?(:broadcast_to)

      logger.broadcast_to(build)
      true
    end
  end
end
