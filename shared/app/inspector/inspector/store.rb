module Inspector
  module Store
    CAP = 50
    MUTEX = Mutex.new
    @entries = []

    class << self
      def record(entry)
        MUTEX.synchronize do
          @entries << entry
          @entries.shift while @entries.size > CAP
        end
        entry
      end

      def latest
        MUTEX.synchronize { @entries.reverse_each.find(&:tracked?) }
      end

      # Most recent first.
      def recent(n = 10)
        MUTEX.synchronize { @entries.last(n).reverse }
      end

      def find(request_id)
        MUTEX.synchronize { @entries.find { |e| e.request_id == request_id } }
      end

      def clear
        MUTEX.synchronize { @entries.clear }
      end
    end
  end
end
