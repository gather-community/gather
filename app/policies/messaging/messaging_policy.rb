# frozen_string_literal: true

module Messaging
  # Who can manage a community's texting: set it up, see its settings and (later) its usage. The record
  # is the community, since there's no single messaging model to authorize against, and using it denies
  # admins of other communities.
  class MessagingPolicy < ApplicationPolicy
    alias_method :community, :record

    def administer?
      active_admin?
    end

    # The setup form's fields (Messaging::SetupForm).
    def permitted_attributes
      %i[package_cents legal_name display_name entity_type ein street city state postal_code email phone
        website accept_fees]
    end
  end
end
