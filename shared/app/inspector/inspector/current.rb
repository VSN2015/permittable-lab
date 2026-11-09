module Inspector
  # The entry of the request running on this thread.
  module Current
    KEY = :inspector_current_entry

    module_function

    def entry = Thread.current[KEY]
    def entry=(value)
      Thread.current[KEY] = value
    end
  end
end
