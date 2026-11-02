# frozen_string_literal: true

# == Schema Information
#
# Table name: feature_flags
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  interface  :string           default("basic"), not null
#  name       :string(64)       not null
#  status     :boolean
#  updated_at :datetime         not null

# A flag that indicates whether a feature is enabled.
class FeatureFlag < ApplicationRecord
  NAME_MAX_LENGTH = 64

  # The admin UI presents a flag as being in one of these modes, which map onto interface and status.
  # Setting the mode here doesn't touch the user list; Admin::FeatureFlagForm clears it when a flag
  # is saved in a mode other than selected users.
  MODES = %i[off selected_users everyone].freeze

  has_many :feature_flag_users, dependent: :destroy, inverse_of: :feature_flag
  has_many :users, through: :feature_flag_users

  scope :by_name, -> { order(:name) }

  def self.lookup(name)
    find_by(name: name) || new(name: name, interface: "basic", status: false)
  end

  def on?(user = nil)
    if interface == "basic"
      status
    else
      raise ArgumentError, "user required" if user.nil?
      feature_flag_users.exists?(user: user)
    end
  end

  def mode
    if interface == "user"
      :selected_users
    else
      status ? :everyone : :off
    end
  end

  def mode=(mode)
    case mode&.to_sym
    when :off then assign_attributes(interface: "basic", status: false)
    when :selected_users then assign_attributes(interface: "user")
    when :everyone then assign_attributes(interface: "basic", status: true)
    else raise ArgumentError, "invalid mode: #{mode.inspect}"
    end
  end
end
