# frozen_string_literal: true

# Models user setting for user interface feature flags.
class FeatureFlagUser < ApplicationRecord
  belongs_to :feature_flag
  belongs_to :user
end
