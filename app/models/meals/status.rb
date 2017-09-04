module Meals
  class Status
    attr_reader :meal

    AUTO_CLOSE_LEAD_TIME = 1.day
    STATUSES = %i(open closed finalized cancelled)

    delegate :status, :served_at, :spots_left, to: :meal

    def initialize(meal)
      @meal = meal
    end

    STATUSES.each do |s|
      define_method("#{s}?") do
        status == s.to_s
      end
    end

    def close!
      raise ArgumentError.new("invalid status for closing") unless closeable?
      set_status("closed")
    end

    def reopen!
      raise ArgumentError.new("invalid status for reopening") unless reopenable?
      set_status("open")
    end

    def finalize!
      raise ArgumentError.new("invalid status for finalizing") unless finalizable?
      set_status("finalized")
    end

    def cancel!
      raise ArgumentError.new("invalid status for cancelling") unless cancelable?
      set_status("cancelled")
    end

    def closeable?
      open?
    end

    def reopenable?
      closed? && !day_in_past?
    end

    def cancelable?
      !cancelled? && !finalized?
    end

    def full?
      spots_left == 0
    end

    def finalizable?
      closed? && in_past?
    end

    def new_signups_allowed?
      !closed? && !cancelled? && !full? && !in_past?
    end

    def signups_editable?
      !closed? && !cancelled? && !in_past?
    end

    def in_past?
      served_at && served_at < Time.current
    end

    def day_in_past?
      served_at && served_at < Time.current.midnight
    end

    private

    def set_status(value)
      meal.update_attribute(:status, value)
    end

    def past_auto_close_time?
      Time.current > served_at - AUTO_CLOSE_LEAD_TIME
    end

    def close_if_past_auto_close_time!
      close! if open? && past_auto_close_time?
    end
  end
end
