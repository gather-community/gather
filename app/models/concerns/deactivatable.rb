module Deactivatable
  extend ActiveSupport::Concern

  included do
    scope :active, -> { where(deactivated_at: nil) }
  end

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
