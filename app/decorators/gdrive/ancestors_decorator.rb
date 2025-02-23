# frozen_string_literal: true

module GDrive
  class AncestorsDecorator < ApplicationDecorator
    attr_accessor :ancestors

    delegate :any?, to: :ancestors

    def initialize(ancestors)
      self.ancestors = ancestors
    end

    def links
      anchors = ancestors.map do |anc|
        is_drive = anc.is_a?(Google::Apis::DriveV3::Drive)
        path = h.gdrive_browse_path(anc.id, drive: is_drive ? 1 : nil)
        h.link_to(anc.name, path)
      end
      safe_join(anchors, h.tag.span(" > ", class: "divider"))
    end
  end
end
