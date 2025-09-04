# frozen_string_literal: true

# == Schema Information
#
# Table name: gdrive_tokens
#
#  id               :bigint           not null, primary key
#  cluster_id       :bigint           not null
#  created_at       :datetime         not null
#  data             :text             not null
#  gdrive_config_id :bigint           not null
#  google_user_id   :string           not null
#  updated_at       :datetime         not null
#
module GDrive
  class Token < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :gdrive_config, class_name: "GDrive::Config"
  end
end
