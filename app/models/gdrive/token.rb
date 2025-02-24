# frozen_string_literal: true

# == Schema Information
#
# Table name: gdrive_tokens
#
#  id               :bigint           not null, primary key
#  data             :text             not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  cluster_id       :bigint           not null
#  gdrive_config_id :bigint           not null
#  google_user_id   :string           not null
#
# Indexes
#
#  index_gdrive_tokens_on_cluster_id        (cluster_id)
#  index_gdrive_tokens_on_gdrive_config_id  (gdrive_config_id)
#
# Foreign Keys
#
#  fk_rails_...  (cluster_id => clusters.id)
#  fk_rails_...  (gdrive_config_id => gdrive_configs.id)
#
module GDrive
  class Token < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :gdrive_config, class_name: "GDrive::Config"
  end
end
