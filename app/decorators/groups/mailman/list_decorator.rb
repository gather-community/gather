# frozen_string_literal: true

module Groups
  module Mailman
    class ListDecorator < ApplicationDecorator
      delegate_all

      def additional_members_ul
        email_ul(additional_members)
      end

      def additional_senders_ul
        # We don't want to show all of these as there can be quite a few and it's not as sensitive
        # as additional members.
        email_ul(additional_senders, initially_visible: 10)
      end

      def panel_url
        return @panel_url if @panel_url
        path = remote_id ? "/mailman3/lists/#{remote_id}/" : "/mailman3/lists/"
        @panel_url = "#{Settings.mailman.single_sign_on.init_url}#{CGI.escape(path)}"
      end

      def archives_url
        return @archives_url if @archives_url
        path = remote_id ? "/archives/list/#{fqdn_listname}/" : "/archives/"
        @archives_url = "#{Settings.mailman.single_sign_on.init_url}#{CGI.escape(path)}"
      end

      private

      def email_ul(emails, initially_visible: nil)
        overflow = initially_visible.nil? ? 0 : emails.size - initially_visible
        items = []
        emails.each_with_index do |email, index|
          li_attribs = if initially_visible && index >= initially_visible
            {class: "hidden", "data-partial-list-target": "overflow"}
          else
            {}
          end
          items << h.content_tag(:li, h.link_to(email, "mailto:#{email}"), **li_attribs)
        end

        buttons = if initially_visible && emails.size > initially_visible
          [
            h.content_tag(:button, "Show #{overflow} more", class: "btn btn-link", "data-action": "partial-list#toggle", "data-partial-list-target": "showButton"),
            h.content_tag(:button, "Hide", class: "hidden btn btn-link", "data-action": "partial-list#toggle", "data-partial-list-target": "hideButton")
          ]
        else
          []
        end
        h.content_tag(:div, "data-controller": "partial-list") do
          h.content_tag(:ul, h.safe_join(items), class: "no-bullets") << h.safe_join(buttons, "")
        end
      end
    end
  end
end
