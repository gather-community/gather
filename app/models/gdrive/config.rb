# frozen_string_literal: true

# == Schema Information
#
# Table name: gdrive_configs
#
#  id            :bigint           not null, primary key
#  client_id     :string           not null
#  client_secret :string           not null
#  cluster_id    :bigint           not null
#  community_id  :bigint           not null
#  created_at    :datetime         not null
#  org_user_id   :string(255)
#  updated_at    :datetime         not null
#
module GDrive
  # Stores configuration information for GDrive connection.
  class Config < ApplicationRecord
    acts_as_tenant :cluster

    # Holds a new client secret to write to the db.
    # We don't want to ever expose the existing client secret in the form.
    attr_accessor :client_secret_to_write

    before_save do
      if client_secret_to_write.present?
        self.client_secret = client_secret_to_write
      end
    end

    belongs_to :community
    has_many :tokens, class_name: "GDrive::Token",
      foreign_key: :gdrive_config_id,
      inverse_of: :gdrive_config,
      dependent: :destroy
    has_many :items, class_name: "GDrive::Item",
      foreign_key: :gdrive_config_id,
      inverse_of: :gdrive_config,
      dependent: :destroy

    validates :client_id, format: /\.apps\.googleusercontent\.com\z/
    validates :client_secret_to_write, length: {is: 35}, if: :new_record?
    validates :org_user_id, format: Devise.email_regexp

    # We require the full drive scope, which is not a problem
    # because its connected app is marked "internal".
    def drive_api_scope
      "https://www.googleapis.com/auth/drive"
    end
  end
end
