module Inspector
  # Prepended into BaseController. Watches permitted_params; never calls it itself.
  module ControllerObserver
    def permitted_params(*args)
      result = super
      entry = Current.entry
      entry.permitted = result.respond_to?(:to_h) ? result.to_h.deep_dup : result if entry
      result
    rescue Permittable::InvalidParameters => e
      entry = Current.entry
      if entry
        entry.rejected = true
        entry.violations = Array(e.details).map do |d|
          d = d.to_h.symbolize_keys
          { param: d[:param], code: d[:code], message: d[:message] }
        end
      end
      raise
    end
  end
end
