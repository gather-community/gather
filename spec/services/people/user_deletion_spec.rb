# frozen_string_literal: true

require "rails_helper"

describe People::UserDeletion do
  let(:community) { Defaults.community }
  let(:actor) { create(:admin) }

  describe "#perform!" do
    let!(:user) { create(:user) }

    it "reassigns authored records to the community's Deleted Member and destroys the user" do
      meal = create(:meal, creator: user)
      page = create(:wiki_page, creator: user, updater: user)
      event = create(:event, creator: user)
      import = create(:meal_import, user: user)

      described_class.new(user: user, actor: actor).perform!

      expect(User.exists?(user.id)).to be(false)
      placeholder = community.deleted_member
      expect(placeholder).to be_deleted_placeholder
      expect(placeholder).not_to be_active
      expect(meal.reload.creator).to eq(placeholder)
      expect(page.reload.creator).to eq(placeholder)
      expect(page.updater).to eq(placeholder)
      expect(event.reload.creator).to eq(placeholder)
      expect(import.reload.user).to eq(placeholder)
    end

    it "cascade-destroys the user's dependent records" do
      meal = create(:meal, head_cook: user)
      expect(Meals::Assignment.where(user: user)).to be_present

      described_class.new(user: user, actor: actor).perform!

      expect(Meals::Assignment.where(user_id: user.id)).to be_empty
      # The meal itself (created by someone else) survives.
      expect(Meals::Meal.exists?(meal.id)).to be(true)
    end

    it "reassigns cross-community events to the event's own community's placeholder" do
      other_community = create(:community, name: "Other", slug: "other", abbrv: "ot")
      calendar = create(:calendar, community: other_community)
      event = create(:event, calendar: calendar, creator: user)

      described_class.new(user: user, actor: actor).perform!

      expect(event.reload.creator).to eq(other_community.deleted_member)
      expect(event.creator.community).to eq(other_community)
    end

    it "refuses to delete the placeholder itself" do
      placeholder = community.deleted_member
      expect { described_class.new(user: placeholder, actor: actor).perform! }
        .to raise_error(People::UndeletableError)
    end
  end

  describe ".blockers" do
    # An account is auto-created for a household in its community; give it a non-zero balance.
    def give_outstanding_balance(household)
      account = household.accounts.first || create(:account, :no_activity, household: household)
      account.update!(total_new_charges: 50)
    end

    it "is empty for a plain adult" do
      expect(described_class.blockers(create(:user))).to eq([])
    end

    it "blocks an adult whose household has an outstanding balance" do
      user = create(:user)
      give_outstanding_balance(user.household)
      expect(described_class.blockers(user)).to include(match(/outstanding balance/))
    end

    it "does NOT block a child whose household has an outstanding balance" do
      household = create(:household, member_count: 0)
      child = create(:user, :child, household: household)
      give_outstanding_balance(household)
      expect(described_class.blockers(child)).to eq([])
    end

    it "blocks a guardian of children" do
      parent = create(:user)
      create(:user, :child, guardians: [parent])
      expect(described_class.blockers(parent)).to include(match(/guardian/))
    end

    it "blocks the last active admin of the community" do
      admin = create(:admin)
      expect(described_class.blockers(admin)).to include(match(/only administrator/))
    end

    it "does not block an admin when another active admin remains" do
      create(:admin)
      admin = create(:admin)
      expect(described_class.blockers(admin)).to eq([])
    end
  end
end
