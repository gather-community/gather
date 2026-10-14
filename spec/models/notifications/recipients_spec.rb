# frozen_string_literal: true

require "rails_helper"

describe Notifications::Recipients do
  # A required kind with the default inactive rule, unless a test says otherwise.
  let(:kind) { :meal_message }
  let(:resolved) { described_class.resolve(targets, kind: kind) }

  context "with fake users" do
    let(:fake1) { create(:user, fake: true) }
    let(:fake2) { create(:user, fake: true) }
    let(:real1) { create(:user) }
    let(:real2) { create(:user) }
    let(:household) { create(:household, users: [fake2, real2]) }
    let(:targets) { [fake1, real1, household] }

    it "leaves them out" do
      expect(resolved).to contain_exactly(real1, real2)
    end
  end

  context "with unconfirmed and inactive adults" do
    let(:unconfirmed1) { create(:user, :unconfirmed) }
    let(:unconfirmed2) { create(:user, :unconfirmed) }
    let(:inactive) { create(:user, :inactive) }
    let(:confirmed1) { create(:user) }
    let(:confirmed2) { create(:user) }
    let(:unconfirmed_child) { create(:user, :child) }
    let(:household) { create(:household, users: [unconfirmed2, confirmed2, inactive]) }
    let(:targets) { [unconfirmed1, confirmed1, household, unconfirmed_child] }

    it "leaves out unconfirmed full-access and inactive users" do
      expect(resolved).to contain_exactly(confirmed1, confirmed2, unconfirmed_child)
    end
  end

  context "with children with own emails" do
    let(:adult1) { create(:user) }
    let(:child1) { create(:user, :child, guardians: [adult1]) }
    let(:adult2) { create(:user) }
    let(:child2) { create(:user, :child, guardians: [adult2]) }
    let(:household) { create(:household, users: [adult2, child2]) }
    let(:targets) { [child1, household] }

    it "reaches them directly" do
      expect(resolved).to contain_exactly(child1, adult2, child2)
    end
  end

  context "with children without own emails" do
    let(:adult1) { create(:user) }
    let(:child1) { create(:user, :child, email: nil, guardians: [adult1]) }
    let(:adult2) { create(:user) }
    let(:adult3) { create(:user) }
    let(:adult4) { create(:user) }
    let(:child2) { create(:user, :child, email: nil, guardians: [adult2, adult4]) }
    let(:household) { create(:household, users: [adult2, adult3, child2]) }
    let(:targets) { [child1, household] }

    it "maps to guardians only when the child is named directly, not via household" do
      expect(resolved).to contain_exactly(adult1, adult2, adult3)
    end
  end

  context "with email addresses and nils" do
    let(:user) { create(:user) }
    let(:targets) { [user, "outside@example.com", "", nil] }

    it "keeps the addresses and drops blanks" do
      expect(resolved).to contain_exactly(user, "outside@example.com")
    end
  end

  describe "inactive rule from the catalog" do
    let(:active) { create(:user) }
    let(:inactive1) { create(:user, :inactive) }
    let(:inactive2) { create(:user, :inactive) }

    context "with :if_no_active (statements)" do
      let(:kind) { :statement_notice }

      it "leaves out inactive members when someone is active" do
        household = create(:household, users: [active, inactive1]).reload
        expect(described_class.resolve(household, kind: kind)).to contain_exactly(active)
      end

      it "includes inactive members when no one is active" do
        household = create(:household, users: [inactive1, inactive2]).reload
        expect(described_class.resolve(household, kind: kind)).to contain_exactly(inactive1, inactive2)
      end
    end

    context "with :always (Drive migration requests)" do
      let(:kind) { :gdrive_migration_request }

      it "includes inactive members" do
        household = create(:household, users: [active, inactive1]).reload
        expect(described_class.resolve(household, kind: kind)).to contain_exactly(active, inactive1)
      end
    end
  end

  describe "notification preferences" do
    let(:opted_out_prefs) { {"meal_reminder" => {"email" => false}} }
    let(:kind) { :meal_reminder }

    context "with a household where one member opted out" do
      let(:adult1) { create(:user, notification_prefs: opted_out_prefs) }
      let(:adult2) { create(:user) }
      let(:targets) { create(:household, users: [adult1, adult2]) }

      it "leaves out the member who opted out" do
        expect(resolved).to contain_exactly(adult2)
      end
    end

    context "with a child without email whose guardian opted out" do
      let(:adult1) { create(:user, notification_prefs: opted_out_prefs) }
      let(:adult2) { create(:user) }
      let(:targets) { create(:user, :child, email: nil, guardians: [adult1, adult2]) }

      it "uses the guardians' preferences" do
        expect(resolved).to contain_exactly(adult2)
      end
    end

    context "with an active member opted out and an inactive member, for an :if_no_active kind" do
      let(:kind) { :statement_reminder }
      let(:adult1) { create(:user, notification_prefs: {"statement_reminder" => {"email" => false}}) }
      let(:adult2) { create(:user, :inactive) }
      let(:targets) { create(:household, users: [adult1, adult2]).reload }

      it "doesn't fall back to the inactive member" do
        expect(resolved).to be_empty
      end
    end

    context "with a required kind" do
      let(:kind) { :meal_message }
      let(:targets) { create(:user, notification_prefs: {"meal_message" => {"email" => false}}) }

      it "ignores stored prefs" do
        expect(resolved).to eq([targets])
      end
    end
  end

  it "rejects an unknown channel" do
    expect { described_class.resolve([], kind: :meal_reminder, channel: :carrier_pigeon) }
      .to raise_error(ArgumentError, /Unknown channel/)
  end
end
