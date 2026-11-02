# frozen_string_literal: true

module Messaging
  # A community's 10DLC registration, as shown on the texting settings page.
  class RegistrationDecorator < ApplicationDecorator
    delegate_all

    def status_label
      h.t("messaging.registration_statuses.#{display_status}")
    end

    # A sentence explaining the status and what happens next.
    def status_explanation
      h.t("messaging.registration_explanations.#{display_status}")
    end

    private

    # Paid but not yet sent to Telnyx reads as "submitting", not "waiting for payment". It only lasts until
    # the next job run.
    def display_status
      (awaiting_payment? && paid_at.present?) ? "submitting" : status
    end

    public

    def entity_type_label
      h.t("simple_form.options.messaging_registration.entity_type.#{entity_type}")
    end

    def submitted_on
      h.l(submitted_at.to_date) if submitted_at
    end

    def approved_on
      h.l(approved_at.to_date) if approved_at
    end
  end
end
