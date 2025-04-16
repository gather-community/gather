# frozen_string_literal: true

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

    validates :client_id, format: /\.apps\.googleusercontent\.com\z/
    validates :client_secret_to_write, length: {is: 35}, if: :new_record?

    def migration?
      type == "GDrive::MigrationConfig"
    end
  end
end
