# frozen_string_literal: true

# == Schema Information
#
# Table name: feature_flag_users
#
#  id              :bigint           not null, primary key
#  created_at      :datetime         not null
#  feature_flag_id :bigint           not null
#  updated_at      :datetime         not null
#  user_id         :bigint           not null
#
# Models user setting for user interface feature flags.
class FeatureFlagUser < ApplicationRecord
  belongs_to :feature_flag
  belongs_to :user
end
