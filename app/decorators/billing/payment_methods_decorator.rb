# frozen_string_literal: true

module Billing
  class PaymentMethodsDecorator < ApplicationDecorator
    delegate_all

    delegate :paypal_me, :paypal_email, :paypal_friend?,
             :check_payee, :check_address, :check_dropoff, :cash_dropoff, :additional_info,
             :show_billing_contact, to: :payment_settings

    def payment_settings
      community.settings.billing.payment_methods
    end

    def payment_badge(type)
      return unless send("pay_with_#{type}?")

      image = h.image_tag("payment-badges/#{type.to_s.tr('_', '-')}.png",
                          class: "payment-badge", alt: t("accounts.payment_badge_alt.#{type}"))
      payment_link(type, image)
    end

    def pay_with_paypal?
      pay_with_paypal_me? || pay_with_paypal_email?
    end

    def pay_with_paypal_me?
      paypal_me
    end

    def pay_with_paypal_email?
      paypal_email
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
      !pay_with_paypal? && !pay_with_online_bill_pay? && !pay_with_check? &&
        !pay_with_cash? && additional_info.nil?
    end

    private

    def payment_link(type, image)
      if type == :paypal
        if pay_with_paypal_me?
          uri = URI.parse(paypal_me)
          uri.path << "/" << h.number_with_precision(balance_due, precision: 2)
          uri = uri.to_s
        else
          uri = "https://paypal.com"
        end
        h.link_to(image, uri, link_attribs(type))
      else
        image
      end
    end

    def link_attribs(type)
      return unless type == :paypal

      if pay_with_paypal_me? && paypal_friend?
        {data: {confirm: "Please **do not** select 'Paying for goods or a service?' if prompted " \
                         "to avoid being charged a fee."}}
      else
        {}
      end
    end
  end
end
