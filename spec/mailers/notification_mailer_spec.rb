require "rails_helper"

describe NotificationMailer do
  describe "shift_reminder" do
    let(:resource) { create(:resource, name: "Foo Place", meal_abbrv: "FOO") }
    let(:meal) { create(:meal, served_at: "2017-01-01 12:00", resources: [resource]) }
    let(:assignment) { create(:assignment, meal: meal, role: "asst_cook") }
    let(:mail) { described_class.shift_reminder(assignment).deliver_now }

    before do
      allow(assignment).to receive(:starts_at).and_return(Time.zone.parse("2017-01-01 11:00"))
      allow(assignment).to receive(:ends_at).and_return(Time.zone.parse("2017-01-01 11:55"))
    end

    it "renders the subject" do
      expect(mail.subject).to eq(
        "Job Reminder: You are Assistant Cook for a meal at Sun Jan 1 11:00am at C1 FOO")
    end

    it "renders the correct times in the body" do
      expect(mail.body.encoded).to match "Your shift is from Sun Jan 1 11:00am - 11:55am at C1 Foo Place"
    end
  end
end
