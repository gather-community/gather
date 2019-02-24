# frozen_string_literal: true

module Billing
  class PaymentMethodsDecorator < ApplicationDecorator
    delegate_all

    delegate :paypal_me, :check_payee, :check_address, :check_dropoff, :cash_dropoff, :additional_info,
      :show_billing_contact, to: :payment_settings

    def payment_settings
      community.settings.billing.payment_methods
    end

    def billing_contact
      community.settings.billing.contact
    end

    def payment_badge(type)
      return unless send("pay_with_#{type}?")
      image = h.image_tag("payment-badges/#{type.to_s.tr('_', '-')}.png",
        class: "payment-badge", alt: t("accounts.payment_badge_alt.#{type}"))
      payment_link(type, image)
    end

    def pay_with_paypal?
      paypal_me
    end

    def pay_with_check?
      check_payee || check_address || check_dropoff
    end

    def pay_with_cash?
      cash_dropoff
    end

    def pay_with_online_bill_pay?
      check_payee && check_address
    end

    def no_payment_instructions?
      paypal_me.nil? && check_payee.nil? && check_address.nil? && check_dropoff.nil? &&
        cash_dropoff.nil? && additional_info.nil?
    end

    private

    def payment_link(type, image)
      if type == :paypal
        uri = URI.parse(paypal_me)
        uri.path << "/" << h.number_with_precision(balance_due, precision: 2)
        h.link_to(image, uri.to_s,
          data: {confirm: "Please **do not** select 'Paying for goods or a service?' if prompted."})
      else
        image
      end
    end
  end
end
