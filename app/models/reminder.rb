# frozen_string_literal: true

# Models a reminder. Abstract class.
class Reminder < ApplicationRecord
  ABS_REL_OPTIONS = %i[relative absolute].freeze
  REL_UNIT_SIGN_OPTIONS = %i[days_before days_after hours_before hours_after].freeze

  acts_as_tenant :cluster

  has_many :deliveries, class_name: "ReminderDelivery", inverse_of: :reminder, dependent: :destroy

  # Used for consistency in display and specs.
  scope :canonical_order, -> { order(:abs_rel, :abs_time, :rel_unit_sign, :rel_magnitude, :note) }

  before_validation :normalize
  after_create :create_or_update_deliveries

  validates :rel_magnitude, presence: true, if: :rel_time?
  validates :abs_time, presence: true, if: :abs_time?

  normalize_attributes :note

  def note?
    note.present?
  end

  def abs_time?
    abs_rel == "absolute"
  end

  def rel_time?
    abs_rel == "relative"
  end

  def rel_after?
    %w[days_after hours_after].include?(rel_unit_sign)
  end

  def rel_sign
    rel_after? ? 1 : -1
  end

  def rel_days?
    %w[days_before days_after].include?(rel_unit_sign)
  end

  def create_or_update_deliveries
    event_ids.each do |event_id|
      if (delivery = deliveries.find_by(event_key => event_id))
        delivery.save! # Run callbacks to ensure recomputation.
      else
        deliveries.create!(event_key => event_id, type: delivery_type)
      end
    end
  end

  private

  def normalize
    if abs_time?
      self.rel_magnitude = nil
      self.rel_unit_sign = nil
    else
      self.abs_time = nil
      if rel_unit_sign.blank? || !REL_UNIT_SIGN_OPTIONS.include?(rel_unit_sign.to_sym)
        self.rel_unit_sign = "days_before"
      end
    end
  end
end
