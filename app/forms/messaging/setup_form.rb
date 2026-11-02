# frozen_string_literal: true

module Messaging
  # The texting setup flow: the community's brand details for 10DLC registration, the monthly package,
  # and one charge that pays the setup fee and the first month together (see
  # Subscription::MessagingTopupManager#start_with_setup!).
  #
  # On save, the registration is stored first as a draft, so a declined card doesn't make the admin
  # type everything in again. Telnyx isn't called here: submission waits until the payment has settled
  # (Messaging::Registration.payment_settled), because Telnyx bills us the moment we submit.
  class SetupForm
    include ActiveModel::Conversion
    include ActiveModel::Validations
    include ActiveModel::Validations::Callbacks
    extend AttributeNormalizer::ClassMethods

    BRAND_FIELDS = %i[legal_name display_name entity_type ein street city state postal_code email phone
      website].freeze

    delegate(*BRAND_FIELDS, to: :registration)
    delegate(*BRAND_FIELDS.map { |f| :"#{f}=" }, to: :registration)

    attr_reader :registration, :community, :subscription
    attr_accessor :accept_fees
    attr_writer :package_cents

    normalize_attributes :legal_name, :display_name, :street, :city, :website
    normalize_attributes :email, with: :email
    normalize_attributes :state, :postal_code

    before_validation { self.state = state&.upcase }

    before_validation :normalize_ein
    before_validation :normalize_phone

    validates :legal_name, :display_name, :entity_type, :ein, :street, :city, :state, :postal_code, :email,
      :phone, :package_cents, presence: true
    validates :legal_name, :display_name, length: {maximum: Registration::NAME_MAX}
    validates :street, :city, length: {maximum: Registration::ADDRESS_MAX}
    validates :email, length: {maximum: Registration::EMAIL_MAX}, format: {with: Devise.email_regexp},
      allow_blank: true
    validates :website, length: {maximum: Registration::WEBSITE_MAX}
    validates :entity_type, inclusion: {in: Registration::ENTITY_TYPES}, allow_blank: true
    validates :state, inclusion: {in: ->(_) { us_states }}, allow_blank: true
    validates :postal_code, format: {with: /\A\d{5}(-\d{4})?\z/}, allow_blank: true
    validates :ein, format: {with: /\A\d{2}-\d{7}\z/}, allow_blank: true
    validates :phone, phony_plausible: {country_code: "US"}, allow_blank: true
    validates :package_cents, inclusion: {in: ->(form) { form.package_options.pluck(:cents) }},
      allow_blank: true
    validates :accept_fees, acceptance: {accept: %w[1 true]}

    def self.model_name
      Registration.model_name
    end

    # The two-letter codes of US states and territories, for the state field.
    def self.us_states
      ISO3166::Country.new("US").subdivisions.keys.sort
    end

    # subscription is the community's populated base Subscription::Subscription, whose Stripe customer
    # and default payment method pay for setup. user is the admin doing it, for the policy.
    def initialize(community:, user:, subscription: nil, params: nil)
      @community = community
      @subscription = subscription
      @registration = community.messaging_registration ||
        Registration.new(community: community, website: default_website)
      return if params.blank?
      params = ActionController::Parameters.new(params) unless params.is_a?(ActionController::Parameters)
      permitted = params.permit(MessagingPolicy.new(user, community).permitted_attributes)
      BRAND_FIELDS.each { |f| send(:"#{f}=", permitted[f]) if permitted.key?(f) }
      @package_cents = permitted[:package_cents]
      @accept_fees = permitted[:accept_fees]
    end

    delegate :model_name, to: :class

    def package_cents
      @package_cents.presence&.to_i
    end

    # The monthly package tiers offered at setup, as {cents:, label:}.
    def package_options
      Subscription::MessagingTopup.options_for(Fees::CURRENCY)
    end

    def setup_cents # rubocop:disable Rails/Delegate -- `delegate to: :Fees` can't resolve the constant here
      Fees.setup_cents
    end

    # Charges the setup fee and first month, and saves the registration. Returns false with errors
    # (including a declined card on :base) if anything fails.
    def save
      return false unless valid?
      registration.status = "draft"
      registration.save!
      invoice = Subscription::MessagingTopupManager.new(community: community, subscription: subscription)
        .start_with_setup!(package_cents, setup_cents: setup_cents)
      registration.update!(status: "awaiting_payment", stripe_invoice_id: invoice.id)
      Stripe::TopupProcessor.new(invoice).credit_if_settled_or_in_flight
      Registration.payment_settled(invoice.id) if invoice.status == "paid"
      true
    rescue Stripe::StripeError => e
      Subscription::EventLog.emit(event_name: "messaging_setup_error", community_id: community.id,
        description: e.message, request_id: e.request_id)
      errors.add(:base, :payment_failed, reason: e.message)
      false
    end

    def persisted?
      false
    end

    private

    delegate :us_states, to: :class

    def default_website
      "#{Settings.url.protocol}://#{community.slug}.#{Settings.url.host}"
    end

    # Stored as Telnyx shows EINs, "12-3456789", however the admin typed it.
    def normalize_ein
      digits = ein.to_s.gsub(/\D/, "")
      self.ein = (digits.length == 9) ? "#{digits[0, 2]}-#{digits[2..]}" : ein.presence
    end

    # Telnyx wants E.164 ("+15551234567").
    def normalize_phone
      return if phone.blank?
      normalized = PhonyRails.normalize_number(phone, country_code: "US")
      self.phone = normalized if Phony.plausible?(normalized)
    end
  end
end
