# frozen_string_literal: true

module Calendars
  class ExportDecorator < ApplicationDecorator
    attr_accessor :community, :user

    def initialize(community, user)
      self.community = community
      self.user = user
    end

    def calendar_link(type, personalized: true)
      h.content_tag(:div) do
        url = calendar_url(type, personalized)
        h.link_to(h.icon_tag("calendar"), url) << " " <<
          h.link_to(Exports::Factory.build(type: type, user: user).calendar_name, url) << h.tag(:br) <<
          h.link_to("Copy Link", url, class: "copy", onclick: "copyTextToClipboard('#{url}'); return false")
      end
    end

    private

    def calendar_url(type, personalized)
      if personalized
        method = :personalized_calendars_export_url
        token = user.calendar_token
      else
        method = :community_calendars_export_url
        token = community.calendar_token
      end

      # If we don't set port to nil then it will be included in the
      # webcal link which some clients don't like.
      h.send(method, type.tr("_", "-"), calendar_token: token, format: :ics, protocol: :webcal, port: nil)
    end
  end
end
