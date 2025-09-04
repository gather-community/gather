# frozen_string_literal: true

# == Schema Information
#
# Table name: reminders
#
#  id            :bigint           not null, primary key
#  abs_rel       :string           default("relative"), not null
#  abs_time      :datetime
#  cluster_id    :integer          not null
#  created_at    :datetime         not null
#  job_id        :bigint
#  note          :string
#  rel_magnitude :decimal(10, 2)
#  rel_unit_sign :string
#  role_id       :bigint
#  type          :string           not null
#  updated_at    :datetime         not null
#
# Models a reminder. Abstract class.
class Reminder < ApplicationRecord
  include Wisper.model

  ABS_REL_OPTIONS = %i[relative absolute].freeze
  REL_UNIT_SIGN_OPTIONS = %i[days_before days_after hours_before hours_after].freeze

  acts_as_tenant :cluster

  has_many :deliveries, class_name: "ReminderDelivery", inverse_of: :reminder, dependent: :destroy

  # Used for consistency in display and specs.
  scope :canonical_order, -> { order(:abs_rel, :abs_time, :rel_unit_sign, :rel_magnitude, :note) }

  before_validation :normalize

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
      self.rel_magnitude = rel_magnitude.to_i if rel_days? && rel_magnitude.present?
    end
  end
end
