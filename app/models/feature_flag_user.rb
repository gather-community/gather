# frozen_string_literal: true

# Models user setting for user interface feature flags.
# == Schema Information
#
# Table name: feature_flag_users
#
#  id              :bigint           not null, primary key
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  feature_flag_id :bigint           not null
#  user_id         :bigint           not null
#
# Indexes
#
#  index_feature_flag_users_on_feature_flag_id              (feature_flag_id)
#  index_feature_flag_users_on_feature_flag_id_and_user_id  (feature_flag_id,user_id) UNIQUE
#  index_feature_flag_users_on_user_id                      (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (feature_flag_id => feature_flags.id)
#  fk_rails_...  (user_id => users.id)
#
class FeatureFlagUser < ApplicationRecord
  belongs_to :feature_flag
  belongs_to :user
end
