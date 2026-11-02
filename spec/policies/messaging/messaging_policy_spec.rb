# frozen_string_literal: true

require "rails_helper"

describe Messaging::MessagingPolicy do
  include_context "policy permissions"

  let(:record) { community }

  permissions :administer? do
    it_behaves_like "permits admins from community"
  end
end
