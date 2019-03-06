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
        credit_exceeded? ? content_tag(:span, num, class: "exceeded") : num
      else
        "None"
      end
    end

    def payment_settings
      community.settings.billing.payment_methods
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

    def pay_with_paypal?
      payment_settings.paypal_me
    end

    def pay_with_check?
      payment_settings.check_payee || payment_settings.check_address || payment_settings.check_dropoff
    end

    def pay_with_cash?
      payment_settings.cash_dropoff
    end

    def pay_with_online_bill_pay?
      payment_settings.check_payee && payment_settings.check_address
    end

    def no_payment_instructions?
      payment_settings.paypal_me.nil? &&
        payment_settings.check_payee.nil? &&
        payment_settings.check_address.nil? &&
        payment_settings.check_dropoff.nil? &&
        payment_settings.cash_dropoff.nil? &&
        payment_settings.additional_info.nil?
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

    private

    def paypal_link(image)
      link_to(image, "#{methods.paypal_me}/#{number_with_precision(account.balance_due, precision: 2)}",
        data: {confirm: "Please **do not** select 'Paying for goods or a service?' if prompted."})
    end
  end
end
