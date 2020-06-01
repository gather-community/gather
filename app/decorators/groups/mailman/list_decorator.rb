# frozen_string_literal: true

module Groups
  module Mailman
    class ListDecorator < ApplicationDecorator
      delegate_all

      def address
        "#{name}@#{domain_name}"
      end

      def additional_members_ul
        membership_ul(additional_members)
      end

      def additional_senders_ul
        membership_ul(additional_senders)
      end

      private

      def membership_ul(memberships)
        items = memberships.sort_by { |m| m.name_or_email.downcase }.map do |membership|
          text = membership.name_or_email
          text << "*" if membership.moderation_action == "hold"
          h.content_tag(:li, h.link_to(text, membership.email))
        end
        h.content_tag(:ul, h.safe_join(items), class: "no-bullets")
      end
    end
  end
end
