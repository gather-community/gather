module Deactivatable
  extend ActiveSupport::Concern

  def activate!
    update_attribute(:deactivated_at, nil)
  end

  def deactivate!
    update_attribute(:deactivated_at, Time.current)
  end

  def active?
    deactivated_at.nil?
  end
end
