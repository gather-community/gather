# frozen_string_literal: true

module Utils
  class TimeUtils
    # Converts number of seconds to a human readable interval with minute precision.
    def self.humanize_interval(secs)
      return "under 1 minute" if secs < 60

      secs, n = secs.divmod(60)
      [[60, "minute"], [10_000_000, "hour"]].map do |count, name|
        if secs > 0
          secs, n = secs.divmod(count)
          n > 0 ? "#{n.to_i} #{name.pluralize(n.to_i)}" : nil
        end
      end.compact.reverse.join(" ")
    end
  end
end
