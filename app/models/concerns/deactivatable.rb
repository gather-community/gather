module Deactivatable
  extend ActiveSupport::Concern

  included do
    scope :active, -> { where(deactivated_at: nil) }
    scope :active_or_selected, ->(ids) { where(deactivated_at: nil).or(where(id: Array.wrap(ids))) }
    scope :deactivated_last, -> { order(arel_table[:deactivated_at].not_eq(nil)) }
  end

  def activate
    update!(deactivated_at: nil)
  end

  def deactivate(options = {})
    update!(deactivated_at: Time.current)
    after_deactivate if respond_to?(:after_deactivate) && !options[:skip_callback]
  end

  def active?
    deactivated_at.nil?
  end

  def inactive?
    !active?
  end
end
