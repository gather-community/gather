# frozen_string_literal: true

module GDrive
  class BrowseDecorator < ApplicationDecorator
    attr_accessor :item_url, :old_item_url

    def initialize
    end

    def footer_links
      links = []
      if item_url
        links << h.link_to("View in Google Drive", item_url)
      end
      safe_join(links, nbsp(3))
    end
  end
end
