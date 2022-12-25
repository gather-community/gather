# frozen_string_literal: true

module GDrive
  class SharedDrive < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :gdrive_config, class_name: "GDrive::Config"
    belongs_to :group, class_name: "Groups::Group"

    scope :in_community, ->(c) { joins(:gdrive_config).where(gdrive_configs: {community_id: c.id}) }

    delegate :community, to: :gdrive_config
  end
end
