# frozen_string_literal: true

require "rails_helper"

describe Groups::Mailman::User do
  describe "factory" do
    it "is valid" do
      create(:group_mailman_user)
    end
  end

  describe "#syncable?" do
    let(:fake) { false }
    let(:mm_list_present) { true }
    let(:user) { create(:user, fake: fake) }
    let!(:mm_user) { create(:group_mailman_user, user: user) }
    let!(:group) { create(:group, availability: "everybody") }
    let!(:mm_list) { create(:group_mailman_list, group: group) if mm_list_present }
    subject(:syncable) { mm_user.syncable? }

    context "with valid memberships and associated mailman list" do
      it { is_expected.to be(true) }
    end

    context "with valid memberships but not for groups with mailman lists" do
      let(:mm_list_present) { false }
      it { is_expected.to be(false) }
    end

    context "when user is fake" do
      let(:fake) { true }
      it { is_expected.to be(false) }
    end
  end
end
