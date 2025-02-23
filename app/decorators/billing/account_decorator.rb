# frozen_string_literal: true

module Billing
  class AccountDecorator < ApplicationDecorator
    delegate_all

    def household_name
      household.decorate.name_with_prefix
    end

    def pos_cur_bal_and_credit_limit?
      positive_current_balance? && credit_limit?
    end

    def credit_limit_or_none
      if credit_limit?
        num = h.number_to_currency(credit_limit)
        credit_exceeded? ? h.tag.span(num, class: "exceeded") : num
      else
        "None"
      end
    end

    def billing_contact
      community.settings.billing.contact
    end

    def payment_badge(type)
      image = h.image_tag("payment-badges/#{type.to_s.tr('_', '-')}.png",
                          class: "payment-badge", alt: t("accounts.payment_badge_alt.#{type}"))
      link_method = "#{type}_link"
      respond_to?(link_method) ? send(link_method, image) : image
    end

    def number_padded
      @number_padded ||= id.to_s.rjust(6, "0")
    end

    def show_action_link_set
      ActionLinkSet.new(
        ActionLink.new(object, :edit, icon: "pencil", path: h.edit_account_path(object)),
        ActionLink.new(object, :add_txn, icon: "plus", path: h.new_account_transaction_path(object))
      )
    end
  end
end
