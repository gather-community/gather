module Meals
  module Statusable
    extend ActiveSupport::Concern

    AUTO_CLOSE_LEAD_TIME = 1.day
    STATUSES = %i(open closed finalized cancelled)

    included do
      scope :open, -> { where(status: "open") }
      scope :not_cancelled, -> { where.not(status: "cancelled") }
      scope :finalizable, -> { past.where.not(status: ["finalized", "cancelled"]) }
      scope :past, -> { where("served_at <= ?", Time.current.midnight) }
      scope :future, -> { where("served_at >= ?", Time.current.midnight) }
      scope :future_or_recent, ->(t) { where("served_at >= ?", Time.current.midnight - t) }
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
      reservations.destroy_all
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
      update_attribute(:status, value)
    end

    def past_auto_close_time?
      Time.current > served_at - AUTO_CLOSE_LEAD_TIME
    end

    def close_if_past_auto_close_time!
      close! if open? && past_auto_close_time?
    end
  end
end
