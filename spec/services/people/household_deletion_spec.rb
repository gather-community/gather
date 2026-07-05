# frozen_string_literal: true

require "rails_helper"

describe People::HouseholdDeletion do
  let(:community) { Defaults.community }
  let(:actor) { create(:admin) }

  describe "#perform!" do
    it "deletes the household, its members, billing accounts, and anonymizes authored records" do
      household = create(:household, member_count: 0)
      member = create(:user, household: household)
      meal = create(:meal, creator: member)
      account = household.accounts.first || create(:account, :no_activity, household: household)

      described_class.new(household: household, actor: actor).perform!

      expect(Household.exists?(household.id)).to be(false)
      expect(User.exists?(member.id)).to be(false)
      expect(Billing::Account.exists?(account.id)).to be(false)
      expect(meal.reload.creator).to eq(community.deleted_member)
    end

    it "refuses to delete the placeholder household" do
      placeholder_household = community.deleted_member.household
      expect { described_class.new(household: placeholder_household, actor: actor).perform! }
        .to raise_error(People::UndeletableError)
    end
  end

  describe ".blockers" do
    it "is empty for a plain household" do
      household = create(:household, member_count: 0)
      create(:user, household: household)
      expect(described_class.blockers(household)).to eq([])
    end

    it "blocks a household with an outstanding balance" do
      household = create(:household, member_count: 0)
      create(:user, household: household)
      account = household.accounts.first || create(:account, :no_activity, household: household)
      account.update!(total_new_charges: 50)
      expect(described_class.blockers(household)).to include(match(/outstanding balance/))
    end

    it "blocks when a member guardians a child in another household" do
      household = create(:household, member_count: 0)
      parent = create(:user, household: household)
      other_household = create(:household, member_count: 0)
      create(:user, :child, household: other_household, guardians: [parent])
      expect(described_class.blockers(household)).to include(match(/guardian of/))
    end

    it "blocks when the household holds the community's only admin" do
      household = create(:household, member_count: 0)
      create(:admin, household: household)
      expect(described_class.blockers(household)).to include(match(/only administrator/))
    end

    it "does not block on last-admin when another admin lives elsewhere" do
      create(:admin)
      household = create(:household, member_count: 0)
      create(:admin, household: household)
      expect(described_class.blockers(household)).to eq([])
    end
  end
end
