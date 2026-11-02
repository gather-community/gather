# frozen_string_literal: true

require "rails_helper"

# Every email to community members ends with a link to the notification settings page (see the mailer
# layout). Configurable notifications also carry a one-click unsubscribe header; that's covered in
# application_mailer_spec.rb.
describe "notification settings footer" do
  let(:user) { create(:user) }
  let(:footer) { %r{Gather notification settings: https?://\S+/notifications\r?$} }

  it "is on required notifications, without unsubscribe headers" do
    meal = create(:meal)
    message = Meals::Message.new(meal: meal, sender: create(:user), body: "Hi")
    mail = MealMailer.normal_message(message, user).deliver_now
    expect(mail.body.encoded).to match(footer)
    expect(mail.body.encoded).to contain_community_url(user.community, "/notifications")
    expect(mail["List-Unsubscribe"]).to be_nil
  end

  it "is on auth emails, pointing at the user's community" do
    mail = AuthMailer.sign_in_invitation(user, "abc").deliver_now
    expect(mail.body.encoded).to match(footer)
    expect(mail.body.encoded).to contain_community_url(user.community, "/notifications")
  end

  context "with a recipient who can't sign in" do
    let(:child) { create(:user, :child, email: "kid@example.com", guardians: [user]) }

    it "isn't on their configurable mail, which still has one-click unsubscribe" do
      meal = create(:meal, head_cook: child)
      mail = MealMailer.with(recipient: child).cook_menu_reminder(meal.assignments[0]).deliver_now
      expect(mail.to).to eq(["kid@example.com"])
      expect(mail.body.encoded).not_to include("Gather notification settings")
      expect(mail["List-Unsubscribe"]).not_to be_nil
    end

    it "isn't on their auth mail" do
      mail = AuthMailer.cant_reset_password(child).deliver_now
      expect(mail.body.encoded).not_to include("Gather notification settings")
    end
  end

  it "isn't on mail that never goes to community members" do
    signup = create(:communities_signup, :approved, reviewed_by: user)
    mail = Communities::SignupMailer.application_approved(signup).deliver_now
    expect(mail.body.encoded).not_to include("Gather notification settings")
  end
end
