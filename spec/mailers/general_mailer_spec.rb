# frozen_string_literal: true

require "rails_helper"

describe "general mailer" do
  describe "mail to inactive user in active household" do
    let(:statement) { create(:statement, total_due: 9.99) }
    let(:user) { create(:user).tap(&:deactivate) }
    let(:meal) { create(:meal, head_cook: user) }
    let(:mail) { MealMailer.cook_menu_reminder(meal.assignments[0]).deliver_now }

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

  describe "mail with no reply_to" do
    let(:cook) { create(:user) }
    let(:meal) { create(:meal, head_cook: cook) }
    let(:mail) { MealMailer.cook_menu_reminder(meal.assignments[0]).deliver_now }

    it "sets reply_to to no reply address" do
      expect(mail.reply_to).to include(Settings.email.no_reply.match(/<(.+)>/)[1])
      expect(mail.from).to include(Settings.email.from.match(/<(.+)>/)[1])
    end
  end
end
