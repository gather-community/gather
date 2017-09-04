module Meals
  class Status
    attr_reader :meal

    AUTO_CLOSE_LEAD_TIME = 1.day

    delegate :status, :served_at, :spots_left, to: :meal

    def initialize(meal)
      @meal = meal
    end

    def close!
      raise ArgumentError.new("invalid status for closing") unless closeable?
      meal.update_attribute(:status, "closed")
    end

    def reopen!
      raise ArgumentError.new("invalid status for reopening") if status != "closed"
      meal.update_attribute(:status, "open")
    end

    def closed?
      status == "closed"
    end

    def finalized?
      status == "finalized"
    end

    def open?
      status == "open"
    end

    def closeable?
      open?
    end

    def full?
      spots_left == 0
    end

    def reopenable?
      closed? && !day_in_past?
    end

    def finalizable?
      closed? && in_past?
    end

    def new_signups_allowed?
      !closed? && !full? && !in_past?
    end

    def signups_editable?
      !closed? && !in_past?
    end

    def in_past?
      served_at && served_at < Time.current
    end

    def day_in_past?
      served_at && served_at < Time.current.midnight
    end

    private

    def past_auto_close_time?
      Time.current > served_at - AUTO_CLOSE_LEAD_TIME
    end

    def close_if_past_auto_close_time!
      close! if open? && past_auto_close_time?
    end
  end
end
