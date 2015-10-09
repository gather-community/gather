# Methods For meal status
module Statusable
  extend ActiveSupport::Concern

  AUTO_CLOSE_LEAD_TIME = 1.day

  def close!
    raise "invalid status for closing" if status != "open"
    update_attribute(:status, "closed")
  end

  def reopen!
    raise "invalid status for reopening" if status != "closed"
    update_attribute(:status, "open")
  end

  def closed?
    status == "closed"
  end

  def open?
    status == "open"
  end

  def closeable?
    open?
  end

  def reopenable?
    closed?
  end

  def new_signups_allowed?
    !closed? && !full?
  end

  def signups_editable?
    !closed?
  end

  def past_auto_close_time?
    Time.now > served_at - AUTO_CLOSE_LEAD_TIME
  end

  def close_if_past_auto_close_time!
    close! if open? && past_auto_close_time?
  end
end