# frozen_string_literal: true

module Messaging
  # Takes the next step on one community's 10DLC registration (see RegistrationSubmitter). Enqueued
  # when the setup payment settles, and by AdvanceRegistrationsJob to poll Telnyx while a step is
  # pending.
  class AdvanceRegistrationJob < ApplicationJob
    # Network errors, Telnyx 5xx and rate limits. Requests Telnyx refuses don't raise; the submitter
    # marks the registration failed instead.
    retry_on Telnyx::Client::RequestError, wait: :polynomially_longer

    def perform(registration_id)
      with_object_in_cluster_context(klass: Registration, id: registration_id) do |registration|
        RegistrationSubmitter.new(registration).advance
      end
    end
  end
end
