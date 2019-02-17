# frozen_string_literal: true

require "rails_helper"

describe "general mailer" do
  describe "mail to household with no emails" do
    let(:statement) { create(:statement, total_due: 9.99) }
    let(:mail) { AccountMailer.statement_notice(statement).deliver_now }

    before do
      statement.household.users.each { |u| u.email = "" }
    end

    it "doesn't send" do
      expect(mail).to be_nil
    end
  end

  describe "mail to child" do
    let(:guardians) { create_list(:user, 2) }
    let(:meal) { create(:meal, head_cook: teen) }
    let(:mail) { MealMailer.cook_menu_reminder(meal.assignments[0]).deliver_now }

    context "with email address" do
      let(:teen) { create(:user, :child, guardians: guardians, email: "teen@foo.com") }

      it "sends to guardians" do
        expect(mail.to).to eq(["teen@foo.com"])
      end
    end

    context "with no email address" do
      let(:teen) { create(:user, :child, guardians: guardians, email: nil) }

      it "sends to guardians" do
        expect(mail.to).to match_array(guardians.map(&:email))
      end
    end
  end
end
