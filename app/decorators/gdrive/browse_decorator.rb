# frozen_string_literal: true

module GDrive
  class BrowseDecorator < ApplicationDecorator
    attr_accessor :item_url, :old_item_url

    def initialize
    end

    def footer_links
      links = []
      links << h.link_to("View in Google Drive", item_url) if item_url
      safe_join(links, nbsp(3))
    end
  end
end
