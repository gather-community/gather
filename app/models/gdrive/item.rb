# frozen_string_literal: true

module GDrive
  class Item < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :gdrive_config, class_name: "GDrive::Config"
    belongs_to :group, class_name: "Groups::Group"

    scope :in_community, ->(c) { joins(:gdrive_config).where(gdrive_configs: {community_id: c.id}) }

    delegate :community, to: :gdrive_config

    attr_accessor :not_found
    alias not_found? not_found

    def self.sync
      all
    end

    def sync
    end
  end
end
