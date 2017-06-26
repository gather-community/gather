require "rails_helper"

describe MealMailer do
  let!(:multiple_communities) { create_list(:community, 2) }
  let(:resource) { create(:resource, name: "Place", meal_abbrv: "CH") }
  let(:ca) { resource.community.abbrv }
  let(:meal) { create(:meal, :with_menu, served_at: "2017-01-01 12:00", resources: [resource]) }

  describe "meal_reminder" do
    let(:user) { create(:user) }
    let(:signup) { create(:signup, household: user.household, meal: meal, adult_meat: 1) }
    let(:mail) { described_class.meal_reminder(user, signup).deliver_now }

    it "sets the right recipient" do
      expect(mail.to).to eq([user.email])
    end

    it "renders the subject" do
      expect(mail.subject).to eq("Meal Reminder: #{meal.title} on Sun Jan 01 12:00pm at #{ca} CH")
    end

    it "renders the correct name and URL in the body" do
      expect(mail.body.encoded).to match("Dear #{user.name}")
      expect(mail.body.encoded).to have_correct_meal_url(meal)
    end
  end

  describe "shift_reminder" do
    let(:assignment) { create(:assignment, meal: meal, role: "asst_cook") }
    let(:mail) { described_class.shift_reminder(assignment).deliver_now }

    before do
      allow(assignment).to receive(:starts_at).and_return(Time.zone.parse("2017-01-01 11:00"))
      allow(assignment).to receive(:ends_at).and_return(Time.zone.parse("2017-01-01 11:55"))
    end

    it "sets the right recipient" do
      expect(mail.to).to eq([assignment.user.email])
    end

    it "renders the subject" do
      expect(mail.subject).to eq(
        "Job Reminder: Assistant Cook for Meal on Sun Jan 01 11:00am at #{ca} CH")
    end

    it "renders the correct times and URL in the body" do
      expect(mail.body.encoded).to match "Your shift is on Sun Jan 01 from 11:00am-11:55am at #{ca} Place."
      expect(mail.body.encoded).to match "The meal is scheduled to be served at 12:00pm."
      expect(mail.body.encoded).to have_correct_meal_url(meal)
    end
  end

  describe "worker_change_notice" do
    let(:initiator) { create(:user) }
    let(:added) { create_list(:assignment, 2, meal: meal, role: "asst_cook") }
    let(:removed) { build_list(:assignment, 2, meal: meal, role: "asst_cook") }
    let(:mail) { described_class.worker_change_notice(initiator, meal, added, removed).deliver_now }

    before do
      meal.community.settings.meals.admin_email = "ma@foo.com"
      meal.community.save!
    end

    it "sets the right recipients" do
      recips = ((added + removed).map(&:user) << initiator << meal.head_cook).map(&:email) + ["ma@foo.com"]
      expect(mail.to).to contain_exactly(*recips)
    end

    it "renders the subject" do
      expect(mail.subject).to eq("Meal Job Assignment Change Notice")
    end

    it "renders the correct URL in the body" do
      expect(mail.body.encoded).to have_correct_meal_url(meal)
    end
  end

  describe "cook_menu_reminder" do
    let(:mail) { described_class.cook_menu_reminder(meal.head_cook_assign).deliver_now }

    it "sets the right recipient" do
      expect(mail.to).to eq([meal.head_cook.email])
    end

    it "renders the subject" do
      expect(mail.subject).to eq("Menu Reminder: Please Post Menu for Sun Jan 01")
    end

    it "renders the correct URL in the body" do
      expect(mail.body.encoded).to have_correct_meal_url(meal)
    end
  end

  describe "diner_message" do
    let!(:sender) { create(:user) }
    let!(:household) { create(:household) }
    let!(:message) { Meals::Message.new(meal: meal, sender: sender, body: "Yo Peeps,\n\nStuff\n\nThx") }
    let!(:mail) { described_class.diner_message(message, household).deliver_now }

    it "sets the right recipients" do
      expect(mail.to).to eq(household.users.map(&:email))
    end

    it "renders the subject" do
      expect(mail.subject).to eq("Message about Meal on Sun Jan 01 12:00pm")
    end

    it "renders the correct name and URL in the body" do
      expect(mail.body.encoded).to match("Dear #{household.name} Household,")
      expect(mail.body.encoded).to have_correct_meal_url(meal)
    end
  end
end
