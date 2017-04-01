require "rails_helper"

describe NotificationMailer do
  describe "shift_reminder" do
    let(:resource) { create(:resource, name: "Place", meal_abbrv: "FOO") }
    let(:ca) { resource.community.abbrv }
    let(:meal) { create(:meal, served_at: "2017-01-01 12:00", resources: [resource]) }
    let(:assignment) { create(:assignment, meal: meal, role: "asst_cook") }
    let(:mail) { described_class.shift_reminder(assignment).deliver_now }

    before do
      allow(assignment).to receive(:starts_at).and_return(Time.zone.parse("2017-01-01 11:00"))
      allow(assignment).to receive(:ends_at).and_return(Time.zone.parse("2017-01-01 11:55"))
    end

    it "renders the subject" do
      expect(mail.subject).to eq(
        "Job Reminder: You are Assistant Cook for a meal at Sun Jan 01 11:00am at #{ca} FOO")
    end

    it "renders the correct times in the body" do
      expect(mail.body.encoded).to match "Your shift is on Sun Jan 01 from 11:00am-11:55am at #{ca} Place."
      expect(mail.body.encoded).to match "The meal is scheduled to be served at 12:00pm."
    end
  end
end
