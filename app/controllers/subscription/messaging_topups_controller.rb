# frozen_string_literal: true

module Subscription
  # Add/change/remove a community's monthly messaging topup. All actions operate on the community's
  # base Subscription (authorized via update_messaging_topup?) and require it to be editable (active,
  # not future-dated, with a payment method on file).
  class MessagingTopupsController < ApplicationController
    # Returns the immediate prorated charge for changing an existing topup to params[:cents], as JSON
    # consumed by the modal. First activation has no proration, so this returns {} (the JS shows the
    # full-month copy instead).
    def preview
      subscription = load_authorize_and_populate
      manager = MessagingTopupManager.new(community: current_community, subscription: subscription)
      render(json: manager.preview(validated_cents) || {})
    end

    def update
      subscription = load_authorize_and_populate
      MessagingTopupManager.new(community: current_community, subscription: subscription)
        .set_amount!(validated_cents)
      redirect_to(subscription_path, notice: t("subscription.messaging_topup.updated"))
    end

    def destroy
      subscription = load_authorize_and_populate
      MessagingTopupManager.new(community: current_community, subscription: subscription).cancel!
      redirect_to(subscription_path, notice: t("subscription.messaging_topup.canceled"))
    end

    private

    def load_authorize_and_populate
      subscription = Subscription.find_by!(community: current_community)
      subscription.populate
      authorize(subscription, :update_messaging_topup?)
      raise Pundit::NotAuthorizedError unless subscription.messaging_topup_editable?
      subscription
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
