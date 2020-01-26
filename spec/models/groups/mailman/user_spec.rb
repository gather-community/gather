# frozen_string_literal: true

require "rails_helper"

describe Groups::Mailman::User do
  describe "factory" do
    it "is valid" do
      create(:group_mailman_user)
    end
  end
end
