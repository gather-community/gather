# frozen_string_literal: true

module Subscription
  # Add/change/remove a community's monthly messaging topup. All actions operate on the community's
  # base Subscription (authorized via update_messaging_topup?) and require it to be editable (active,
  # not future-dated, with a payment method on file). Gated by the messaging feature flag.
  class MessagingTopupsController < ApplicationController
    before_action :verify_messaging_enabled

    # Returns the immediate prorated charge for changing an existing topup to params[:cents], as JSON
    # consumed by the modal. First activation has no proration, so this returns {} (the JS shows the
    # full-month copy instead).
    def preview
      subscription = load_authorize_and_populate
      manager = MessagingTopupManager.new(community: current_community, subscription: subscription)
      render(json: format_preview(manager.preview(validated_cents)))
    end

    # Sets the topup amount (AJAX). Creates/updates the topup subscription and credits the wallet
    # synchronously from the just-finalized invoice — idempotent with the invoice.finalized webhook —
    # so the balance is already correct when the JS reloads the page. On a Stripe error we return a
    # clear reason plus the Stripe request id for a Gather operator. The green success flash is set
    # here and rendered on the reload.
    def update
      subscription = load_authorize_and_populate
      manager = MessagingTopupManager.new(community: current_community, subscription: subscription)
      invoice = manager.set_amount!(validated_cents)
      # Credit synchronously from the just-finalized invoice (idempotent with the webhooks), but only
      # if the payment is already settled or in-flight — same rule as invoice.finalized.
      Stripe::TopupProcessor.new(invoice).credit_if_settled_or_in_flight if invoice
      flash[:success] = t("subscription.messaging_topup.updated", balance: current_balance.format)
      render(json: {ok: true})
    rescue Stripe::StripeError => e
      render_stripe_error(e)
    end

    def destroy
      subscription = load_authorize_and_populate
      MessagingTopupManager.new(community: current_community, subscription: subscription).cancel!
      flash[:success] = t("subscription.messaging_topup.canceled")
      render(json: {ok: true})
    rescue Stripe::StripeError => e
      render_stripe_error(e)
    end

    private

    # Defense in depth: the UI is hidden while the flag is off, but the endpoints must be too.
    def verify_messaging_enabled
      raise Pundit::NotAuthorizedError unless FeatureFlag.lookup("messaging").on?(current_user)
    end

    def current_balance
      account = current_community.reload.messaging_account
      account ? account.balance : Money.new(0, current_community.default_currency || "usd")
    end

    # A clear failure reason plus an operator handle (Stripe request id). The JS adds the local time
    # the user attempted the change.
    def render_stripe_error(error)
      EventLog.emit(event_name: "topup_error", community_id: current_community.id,
        description: error.message, reference: error.request_id)
      render(json: {ok: false, error: error.message, reference: error.request_id},
        status: :unprocessable_entity)
    end

    def load_authorize_and_populate
      subscription = Subscription.find_by!(community: current_community)
      subscription.populate
      authorize(subscription, :update_messaging_topup?)
      raise Pundit::NotAuthorizedError unless subscription.messaging_topup_editable?
      subscription
    end

    # Shapes the manager's raw proration into what the modal JS renders. A negative immediate charge
    # (from a decrease/removal) is presented as a credit. Returns {} when there's nothing to preview
    # (first activation), so the JS falls back to its full-month copy.
    def format_preview(result)
      return {} if result.nil?
      cents = result[:immediate_charge_cents]
      {
        immediate_charge: Money.from_cents(cents.abs, result[:currency]).format,
        is_credit: cents.negative?,
        next_bill_date: I18n.l(result[:next_bill_date])
      }
    end

    # Ensures the posted amount is one of the offered per-currency tiers — never trust the client.
    def validated_cents
      cents = params.require(:cents).to_i
      valid = MessagingTopup.options_for(current_community.default_currency).pluck(:cents)
      raise Pundit::NotAuthorizedError, "Invalid topup amount" unless valid.include?(cents)
      cents
    end
  end
end
