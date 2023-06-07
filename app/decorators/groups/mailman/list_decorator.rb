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
        email_ul(additional_senders, max: 10)
      end

      def panel_url
        return @panel_url if @panel_url
        path = remote_id ? "/postorius/lists/#{remote_id}/" : "/postorius/lists/"
        @panel_url = "#{Settings.mailman.single_sign_on.init_url}#{CGI.escape(path)}"
      end

      def archives_url
        return @archives_url if @archives_url
        path = remote_id ? "/hyperkitty/lists/#{fqdn_listname}/" : "/hyperkitty/"
        @archives_url = "#{Settings.mailman.single_sign_on.init_url}#{CGI.escape(path)}"
      end

      private

      def email_ul(emails, max: nil)
        overflow = max.nil? ? 0 : emails.size - max
        email = emails[0...max] if overflow.positive?
        items = emails.map do |email|
          h.content_tag(:li, h.link_to(email, "mailto:#{email}"))
        end
        items << h.content_tag(:li, "+#{overflow} more") if overflow.positive?
        h.content_tag(:ul, h.safe_join(items), class: "no-bullets")
      end
    end
  end
end
