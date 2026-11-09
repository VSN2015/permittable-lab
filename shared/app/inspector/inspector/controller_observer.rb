module Inspector
  # Prepended into BaseController. Watches permitted_params; never calls it itself.
  # Bookkeeping failures are swallowed so the Inspector can never change the
  # outcome; the original exception is re-raised untouched.
  module ControllerObserver
    def permitted_params(*args)
      result = super
      begin
        entry = Current.entry
        entry.permitted = result.respond_to?(:to_h) ? result.to_h.deep_dup : result if entry
      rescue StandardError
        nil
      end
      result
    rescue Permittable::InvalidParameters => e
      begin
        entry = Current.entry
        if entry
          entry.rejected = true
          entry.violations = Array(e.details).map do |d|
            d = d.to_h.symbolize_keys
            { param: d[:param], code: d[:code], message: d[:message] }
          end
        end
      rescue StandardError
        nil
      end
      raise
    end
  end
end
