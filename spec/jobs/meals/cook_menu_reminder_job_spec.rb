# frozen_string_literal: true

require "rails_helper"

describe Meals::CookMenuReminderJob do
  include_context "jobs"
  include_context "reminder jobs"

  let(:user1) { create(:user) }
  let(:user2) { create(:user) }
  let(:user3) { create(:user) }
  let(:user4) { create(:user) }
  let(:formula) { create(:meal_formula, :with_three_roles) }
  let!(:meal1) do
    create(:meal, *meal1_trait, formula: formula, head_cook: user1, served_at: "2017-01-05")
  end
  let!(:meal2) do
    create(:meal, *meal2_trait, formula: formula, head_cook: user2, served_at: "2017-01-10")
  end
  let!(:meal3) do
    create(:meal, formula: formula, head_cook: user2, cleaners: [user1], served_at: "2017-01-14")
  end
  let!(:meal4) do
    create(:meal, formula: formula, head_cook: user3, served_at: "2017-01-05", status: "cancelled")
  end
  let!(:meal5) do
    create(:meal, formula: formula, head_cook: user4, served_at: "2017-01-10", status: "cancelled")
  end
  subject(:email_sent) { email_sent_by { perform_job } }

  # reminder jobs shared context sets correct time by default
  context "at correct hour" do
    context "both meals without menus" do
      let(:meal1_trait) { nil }
      let(:meal2_trait) { nil }

      it "should send to both normal meals but not cancelled ones" do
        expect(email_sent.map(&:to)).to contain_exactly([meal1.head_cook.email], [meal2.head_cook.email])
        expect(email_sent.first.subject).to match(/\AMenu Reminder: Please Post Menu/)
      end

      context "with early reminders already sent for both meals" do
        before do
          meal1.assignments[0].update_attribute(:cook_menu_reminder_count, 1)
          meal2.assignments[0].update_attribute(:cook_menu_reminder_count, 1)
        end

        it "should send to sooner meal only" do
          expect(email_sent.map(&:to)).to contain_exactly([meal1.head_cook.email])
        end
      end
    end

    context "menu for sooner meal only" do
      let(:meal1_trait) { :with_menu }
      let(:meal2_trait) { nil }

      it "should send to later meal only" do
        expect(email_sent.map(&:to)).to contain_exactly([meal2.head_cook.email])
      end
    end

    context "both meals with menus" do
      let(:meal1_trait) { :with_menu }
      let(:meal2_trait) { :with_menu }

      it "should send to neither meal" do
        expect(email_sent).to be_empty
      end
    end
  end

  context "at incorrect hour" do
    let(:meal1_trait) { nil }
    let(:meal2_trait) { nil }

    it "should send to neither meal" do
      Timecop.freeze(2.hours) do
        expect(email_sent).to be_empty
      end
    end
  end
end
