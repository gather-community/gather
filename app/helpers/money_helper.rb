# frozen_string_literal: true

# Included in every view (Rails includes all helpers) and in mailer views via ApplicationMailer.
module MoneyHelper
  # Formats an amount of money in the community's currency, with the current locale's separators and symbol
  # position: a CAD amount is "$1,234.50" in English and "1 234,50 $" in French. Use this rather than
  # number_to_currency, which takes the currency from the locale and would show euros in French.
  # Pass `currency:` for amounts that aren't the community's, e.g. a Stripe price.
  def format_money(amount, currency: nil)
    return if amount.nil?
    currency ||= current_community&.currency || Community::DEFAULT_CURRENCY
    ERB::Util.html_escape(Money.from_amount(amount, currency).format(sign_before_symbol: true))
  end
end
