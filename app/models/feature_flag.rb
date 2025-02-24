# frozen_string_literal: true

# A flag that indicates whether a feature is enabled.
# == Schema Information
#
# Table name: feature_flags
#
#  id         :bigint           not null, primary key
#  interface  :string           default("basic"), not null
#  name       :string           not null
#  status     :boolean
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_feature_flags_on_name  (name) UNIQUE
#
class FeatureFlag < ApplicationRecord
  has_many :feature_flag_users, dependent: :destroy, inverse_of: :feature_flag
  has_many :users, through: :feature_flag_users

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
end
