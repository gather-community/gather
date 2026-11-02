# frozen_string_literal: true

module Messaging
  # Moves a community's 10DLC registration through Telnyx, one step per call to #advance:
  #
  #   awaiting_payment (paid) -> create the brand                  -> brand_pending
  #   brand_pending           -> once Telnyx verifies the brand,
  #                              create the campaign               -> campaign_pending
  #   campaign_pending        -> once carriers provision it        -> approved
  #
  # Any step can end in `failed`, with Telnyx's reason in failure_reason.
  #
  # Each fee is debited from the community's messaging balance when the Telnyx call that incurs it
  # succeeds, so a rejection before Telnyx bills us leaves the balance untouched. Telnyx calls that fail
  # for transient reasons (network, 5xx, rate limits) raise, so the calling job can retry. Calls Telnyx
  # refuses (4xx) mark the registration failed, because retrying the same request won't help.
  #
  # Runs inside the community's tenant. Callers serialize on the registration (see #advance).
  class RegistrationSubmitter
    # Telnyx's brand identityStatus values that let a campaign be submitted.
    VERIFIED_IDENTITIES = %w[VERIFIED VETTED_VERIFIED].freeze

    # The vertical we register every community under. Telnyx's list has no category for residential
    # communities; REAL_ESTATE is the closest.
    VERTICAL = "REAL_ESTATE"

    # Campaign statuses. MNO_PROVISIONED is the end of the success path
    # (TCR_PENDING -> TCR_ACCEPTED -> MNO_PENDING -> MNO_PROVISIONED). A new campaign's separate `status`
    # field defaults to ACTIVE, so it says nothing about approval.
    CAMPAIGN_APPROVED = "MNO_PROVISIONED"
    CAMPAIGN_FAILED = %w[TCR_FAILED TELNYX_FAILED MNO_REJECTED MNO_PROVISIONING_FAILED].freeze

    attr_reader :registration, :client

    def initialize(registration, client: Telnyx::Client.new)
      @registration = registration
      @client = client
    end

    # Takes the next step if there is one. Safe to call repeatedly: a step whose answer isn't in yet is
    # a no-op, and the row lock stops two runs submitting the same thing twice.
    def advance
      registration.with_lock do
        case registration.status
        when "awaiting_payment" then submit_brand if registration.paid_at
        when "brand_pending" then check_brand
        when "campaign_pending" then check_campaign
        end
      end
    end

    private

    def submit_brand
      response = refusable { client.create_brand(**brand_attributes) }
      return if response.nil?
      debit(:brand_registration, Fees::BRAND_REGISTRATION_CENTS)
      registration.update!(status: "brand_pending", telnyx_brand_id: response.fetch("brandId"),
        brand_identity_status: response["identityStatus"], submitted_at: Time.current)
      log("brand_submitted")
      check_brand_status(response)
    end

    def check_brand
      check_brand_status(client.brand(registration.telnyx_brand_id))
    end

    def check_brand_status(brand)
      registration.update!(brand_identity_status: brand["identityStatus"])
      if brand["status"] == "REGISTRATION_FAILED" ||
          (brand["status"] == "OK" && brand["identityStatus"] == "UNVERIFIED")
        fail_with(brand["failureReasons"].presence || brand["identityStatus"])
      elsif brand["status"] == "OK" && VERIFIED_IDENTITIES.include?(brand["identityStatus"])
        submit_campaign
      end
    end

    def submit_campaign
      template = CampaignTemplate.new(registration.community)
      response = refusable {
        client.create_campaign(**template.to_telnyx(brand_id: registration.telnyx_brand_id))
      }
      return if response.nil?
      debit(:campaign_review, Fees::CAMPAIGN_REVIEW_CENTS)
      debit(:campaign_prepaid, Fees::CAMPAIGN_MONTHLY_CENTS * Fees::CAMPAIGN_PREPAID_MONTHS)
      registration.update!(status: "campaign_pending", telnyx_campaign_id: response.fetch("campaignId"),
        campaign_status: response["campaignStatus"], campaign_version: template.version)
      log("campaign_submitted")
    end

    def check_campaign
      campaign = client.campaign(registration.telnyx_campaign_id)
      status = campaign["campaignStatus"]
      registration.update!(campaign_status: status)
      if status == CAMPAIGN_APPROVED
        registration.update!(status: "approved", approved_at: Time.current)
        log("campaign_approved")
      elsif CAMPAIGN_FAILED.include?(status)
        fail_with(campaign["failureReasons"].presence || status)
      end
    end

    def brand_attributes
      {
        entityType: registration.entity_type,
        displayName: registration.display_name,
        companyName: registration.legal_name,
        ein: registration.ein,
        country: "US",
        email: registration.email,
        phone: registration.phone,
        street: registration.street,
        city: registration.city,
        state: registration.state,
        postalCode: registration.postal_code,
        website: registration.website.presence,
        vertical: VERTICAL
      }.compact
    end

    # Runs a Telnyx create call. A 4xx means Telnyx refused this request, which retrying won't change,
    # so the registration fails with Telnyx's message and this returns nil. Anything else re-raises for
    # the job to retry.
    def refusable
      yield
    rescue Telnyx::Client::RequestError => e
      raise if e.status.nil? || e.status >= 500 || e.status == 429
      Gather::ErrorReporter.instance.report(e, data: {registration_id: registration.id})
      fail_with(e.body.presence || e.message)
      nil
    end

    def fail_with(reason)
      registration.update!(status: "failed", failure_reason: reason.to_s)
      log("registration_failed", reason: reason.to_s)
    end

    def debit(fee, cents)
      account = Account.find_or_create_by!(community: registration.community) { |a| a.currency = Fees::CURRENCY }
      account.transactions.create!(amount_cents: -cents, description: I18n.t("messaging.fees.#{fee}"))
    end

    def log(event, **data)
      Rails.logger.info("Messaging registration #{event}", registration_id: registration.id,
        community_id: registration.community_id, **data)
    end
  end
end
