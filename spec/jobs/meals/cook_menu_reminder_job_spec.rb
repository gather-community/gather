# frozen_string_literal: true

require "rails_helper"

describe Meals::CookMenuReminderJob do
  include_context "jobs"
  include_context "reminder jobs"

  let(:user1) { create(:user) }
  let(:user2) { create(:user) }
  let(:user3) { create(:user) }
  let(:user4) { create(:user) }
  let!(:meal1) { create(:meal, *meal1_trait, head_cook: user1, served_at: "2017-01-05") }
  let!(:meal2) { create(:meal, *meal2_trait, head_cook: user2, served_at: "2017-01-10") }
  let!(:meal3) { create(:meal, head_cook: user2, cleaners: [user1], served_at: "2017-01-14") }
  let!(:meal4) { create(:meal, head_cook: user3, served_at: "2017-01-05", status: "cancelled") }
  let!(:meal5) { create(:meal, head_cook: user4, served_at: "2017-01-10", status: "cancelled") }
  subject(:mails) { mails_sent }

  # reminder jobs shared context sets correct time by default
  context "at correct hour" do
    context "both meals without menus" do
      let(:meal1_trait) { nil }
      let(:meal2_trait) { nil }

      it "should send to both normal meals but not cancelled ones" do
        expect(mails.map(&:to)).to contain_exactly([meal1.head_cook.email], [meal2.head_cook.email])
        expect(mails.first.subject).to match(/\AMenu Reminder: Please Post Menu/)
      end

      context "with early reminders already sent for both meals" do
        before do
          meal1.head_cook_assign.update_attribute(:reminder_count, 1)
          meal2.head_cook_assign.update_attribute(:reminder_count, 1)
        end

        it "should send to sooner meal only" do
          expect(mails.map(&:to)).to contain_exactly([meal1.head_cook.email])
        end
      end
    end

    context "menu for sooner meal only" do
      let(:meal1_trait) { :with_menu }
      let(:meal2_trait) { nil }

      it "should send to later meal only" do
        expect(mails.map(&:to)).to contain_exactly([meal2.head_cook.email])
      end
    end

    context "both meals with menus" do
      let(:meal1_trait) { :with_menu }
      let(:meal2_trait) { :with_menu }

      it "should send to neither meal" do
        expect(mails).to be_empty
      end
    end
  end

  context "at incorrect hour" do
    let(:meal1_trait) { nil }
    let(:meal2_trait) { nil }

    it "should send to neither meal" do
      Timecop.freeze(2.hours) do
        expect(mails).to be_empty
      end
    end
  end
end
