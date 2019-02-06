module Meals
  class Status
    attr_reader :meal

    AUTO_CLOSE_LEAD_TIME = 1.day
    STATUSES = %i(open closed finalized cancelled)

    delegate :status, :served_at, :spots_left, to: :meal

    def self.define_scopes(c)
      c.scope :open, -> { c.where(status: "open") }
      c.scope :not_cancelled, -> { c.where.not(status: "cancelled") }
      c.scope :finalizable, -> { c.past.where.not(status: ["finalized", "cancelled"]) }
      c.scope :past, -> { c.where("served_at <= ?", Time.current.midnight) }
      c.scope :future, -> { c.where("served_at >= ?", Time.current.midnight) }
      c.scope :future_or_recent, ->(t) { c.where("served_at >= ?", Time.current.midnight - t) }
    end

    def initialize(meal)
      @meal = meal
    end

    STATUSES.each do |s|
      define_method("#{s}?") do
        status == s.to_s
      end
    end

    def close!
      set_status("closed")
    end

    def reopen!
      set_status("open")
    end

    def finalize!
      set_status("finalized")
    end

    def cancel!
      set_status("cancelled")
      meal.reservations.destroy_all
    end

    def full?
      spots_left == 0
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
