# frozen_string_literal: true

module Subscription
  # Drives the self-serve subscription signup: the customer picks a tier and billing period,
  # confirms the seat count, and enters a billing address (via the Stripe Address Element, which
  # writes the address_* fields as hidden inputs). On save we build an in-memory Intent and hand it
  # to Registrar, which creates the Stripe subscription; the customer then pays on the existing
  # payment page.
  #
  # Currency is not chosen here — it follows the community's country (Community#default_currency),
  # so prices are known server-side at render time. The billing address is restricted to the
  # countries Gather can bill in (Community::COUNTRY_CURRENCIES), both in the Address Element and
  # here on the server.
  class SignupForm
    include ActiveModel::Model
    extend AttributeNormalizer::ClassMethods

    PERIODS = [1, 12].freeze

    # Which Stripe payment methods to offer, by billing country. Bank debit varies by country and
    # only works in our in-app Elements flow (not Checkout/Portal), which is why we collect payment
    # in-app. Everywhere else is card-only.
    PAYMENT_METHOD_TYPES = {
      "US" => %w[us_bank_account card],
      "CA" => %w[acss_debit card]
    }.freeze
    DEFAULT_PAYMENT_METHOD_TYPES = %w[card].freeze

    attr_accessor :community, :tier, :contact_email
    attr_reader :months_per_period, :quantity
    attr_accessor(*Intent::ADDRESS_ATTRIBS)

    normalize_attributes :address_line1, :address_line2, :address_city, :address_state,
      :address_postal_code
    normalize_attributes :contact_email, with: :email

    # ISO country codes must be uppercase to match Community::COUNTRY_CURRENCIES. There's no
    # built-in :upcase normalizer, so normalize here.
    def address_country=(value)
      @address_country = value.to_s.strip.upcase.presence
    end

    # Select params arrive as strings; coerce so the integer inclusion/numericality checks apply.
    def months_per_period=(value)
      @months_per_period = value.blank? ? value : value.to_i
    end

    def quantity=(value)
      @quantity = value.blank? ? value : value.to_i
    end

    # tier/period come from selects, so a real user never trips these; they guard tampering.
    validates :tier, inclusion: {in: PriceCalculator::TIERS}
    validates :months_per_period, inclusion: {in: PERIODS}
    validates :quantity, numericality: {only_integer: true, greater_than: 0}
    validates :contact_email, presence: true
    validates :contact_email, format: {with: Devise.email_regexp}, allow_blank: true
    validates :address_line1, :address_city, :address_country, presence: true
    validate :country_billable

    def self.model_name
      ActiveModel::Name.new(self, nil, "Subscription::Signup")
    end

    def initialize(community:, params: nil)
      super()
      @community = community
      # Defaults for the blank form; any submitted params below win.
      @tier = "standard"
      @months_per_period = 1
      @quantity = community.billable_seat_count
      return if params.blank?
      params = ActionController::Parameters.new(params) unless params.is_a?(ActionController::Parameters)
      assign_attributes(params.permit(*SubscriptionPolicy.permitted_attributes).to_h)
    end

    def save
      return false unless valid?
      Registrar.new(intent: intent).register
      true
    end

    def intent
      @intent ||= Intent.new(
        community: community,
        contact_email: contact_email,
        tier: tier,
        months_per_period: months_per_period.to_i,
        quantity: quantity.to_i,
        payment_method_types: payment_method_types,
        **Intent::ADDRESS_ATTRIBS.index_with { |a| public_send(a) }
      )
    end

    def currency
      community.default_currency
    end

    # The per-period price in cents for a tier/period combo, for rendering the plan picker.
    def price_cents(tier, months)
      PriceCalculator.new(tier: tier, currency: currency, months_per_period: months).unit_amount_cents
    end

    def payment_method_types
      PAYMENT_METHOD_TYPES.fetch(address_country, DEFAULT_PAYMENT_METHOD_TYPES)
    end

    private

    def country_billable
      return if address_country.blank?
      return if Community::COUNTRY_CURRENCIES.key?(address_country)
      errors.add(:address_country, "is not a country we can bill in yet")
    end
  end
end
