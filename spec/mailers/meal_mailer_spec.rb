# frozen_string_literal: true

require "rails_helper"

describe MealMailer do
  let!(:multiple_communities) { create_list(:community, 2) }
  let(:calendar) { create(:calendar, name: "Place", abbrv: "CH") }
  let(:ca) { calendar.community.abbrv }
  let(:head_cook_role) { create(:meal_role, :head_cook, description: "Cook something tasty") }
  let(:asst_cook_role) do
    create(:meal_role, title: "Assistant Cook", time_type: "date_time",
                       shift_start: -90, shift_end: -5, description: "Assist the wise cook")
  end
  let(:taster_role) { create(:meal_role, title: "Taster", time_type: "date_only") }
  let(:formula) { create(:meal_formula, roles: [head_cook_role, asst_cook_role, taster_role]) }
  let(:served_at) { Time.zone.parse("2017-01-01 12:00") }
  let(:meal) { create(:meal, :with_menu, served_at: served_at, formula: formula, calendars: [calendar]) }

  # This tests fake user handling for mails with a household recipient.
  describe "meal_reminder with fake user" do
    let(:users) { create_list(:user, 2) }
    let(:fake_user) { create(:user, fake: true) }
    let(:household) { create(:household, users: users + [fake_user]) }
    let(:signup) do
      create(:meal_signup, household: household, meal: meal, comments: "Foo\nBar", diner_counts: [2, 1])
    end
    let(:mail) { described_class.meal_reminder(signup).deliver_now }

    it "sets the right recipient" do
      expect(mail.to).to match_array(users.map(&:email))
    end

    it "renders the subject" do
      expect(mail.subject).to eq("Meal Reminder: Sun Jan 01 12:00pm - #{meal.title} at #{ca} CH")
    end

    it "renders the correct name and URL in the body" do
      expect(mail.body.encoded).to match("Dear #{household.name} Household")
      expect(mail.body.encoded).to have_correct_meal_url(meal)
      expect(mail.body.encoded).to match(/Foo\s+Bar/m)
    end
  end

  describe "role_reminder" do
    let(:reminder) { double(note?: false) }
    let(:mail) { described_class.role_reminder(assignment, reminder).deliver_now }

    context "for role with date_time" do
      let(:assignment) { create(:meal_assignment, meal: meal, role: asst_cook_role) }

      context "without note" do
        it "sets the right recipient" do
          expect(mail.to).to eq([assignment.user.email])
        end

        it "renders the subject" do
          expect(mail.subject).to eq("Job Reminder: Assistant Cook on Sun Jan 01 10:30am at #{ca} CH")
        end

        it "renders the correct times and URL in the body" do
          expect(mail.body.encoded).to match("Your shift is on Sun Jan 01 10:30am–11:55am at #{ca} Place.")
          expect(mail.body.encoded).to match("The meal is scheduled to be served at 12:00pm.")
          expect(mail.body.encoded).not_to match("includes the following note")
          expect(mail.body.encoded).to have_correct_meal_url(meal)
        end
      end

      context "with note" do
        let(:reminder) { double(note?: true, note: "Hi there! And stuff.") }

        it "renders the subject" do
          expect(mail.subject).to eq("Job Reminder: Assistant Cook on Sun Jan 01 10:30am at #{ca} CH " \
                                     "(Hi there! And stuff.)")
        end

        it "renders the correct times and URL in the body" do
          expect(mail.body.encoded).to match("includes the following note:")
          expect(mail.body.encoded).to match("Hi there! And stuff.")
        end
      end
    end

    context "for role with date_only" do
      let(:assignment) { create(:meal_assignment, meal: meal, role: taster_role) }

      it "sets the right recipient" do
        expect(mail.to).to eq([assignment.user.email])
      end

      it "renders the subject" do
        expect(mail.subject).to eq("Job Reminder: Taster on Sun Jan 01 at #{ca} CH")
      end

      it "renders the correct times and URL in the body" do
        expect(mail.body.encoded).to match("Your shift is on Sun Jan 01 at #{ca} Place.")
        expect(mail.body.encoded).to match("The meal is scheduled to be served at 12:00pm.")
        expect(mail.body.encoded).to have_correct_meal_url(meal)
      end
    end
  end

  describe "worker_change_notice" do
    let(:initiator) { create(:user) }
    let(:added) { create_list(:meal_assignment, 2, meal: meal, role: asst_cook_role) }
    let(:removed) { build_list(:meal_assignment, 2, meal: meal, role: asst_cook_role) }
    let(:mail) { described_class.worker_change_notice(initiator, meal, added, removed).deliver_now }
    let!(:meal_coords) { create_list(:meals_coordinator, 2) }
    let!(:decoy_user) { create(:user) }

    it "sets the right recipients" do
      recips = (added + removed).map(&:user).push(initiator, meal.head_cook, *meal_coords).map(&:email)
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
    let(:mail) { described_class.cook_menu_reminder(meal.assignments[0]).deliver_now }

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

  describe "normal_message" do
    let!(:sender) { create(:user) }
    let!(:message) { Meals::Message.new(meal: meal, sender: sender, body: "Yo Peeps,\n\nStuff\n\nThx") }
    let(:mail) { described_class.normal_message(message, user).deliver_now }

    context "with normal user" do
      let(:user) { create(:user) }

      it "sets the right recipients and reply-to" do
        expect(mail.to).to match_array(user.email)
        expect(mail.reply_to).to contain_exactly(message.sender_email)
      end

      it "renders the subject" do
        expect(mail.subject).to eq("Message about Meal on Sun Jan 01")
      end

      it "renders the correct name and URL in the body" do
        expect(mail.body.encoded).to match("Dear #{user.name},")
        expect(mail.body.encoded).to have_correct_meal_url(meal)
      end
    end

    # This tests fake user handling for mails with a single User recipient.
    context "with fake user" do
      let(:user) { create(:user, fake: true) }

      it "returns nil" do
        expect(mail).to be_nil
      end
    end
  end

  describe "cancellation_message" do
    let!(:sender) { create(:user) }
    let!(:household) { create(:household) }
    let!(:message) { Meals::Message.new(meal: meal, sender: sender, body: "Yo Peeps,\n\nStuff\n\nThx") }
    let(:mail) { described_class.cancellation_message(message, household).deliver_now }

    it "sets the right recipients and reply-to" do
      expect(mail.to).to match_array(household.users.map(&:email))
      expect(mail.reply_to).to contain_exactly(message.sender_email)
    end

    it "renders the subject" do
      expect(mail.subject).to eq("Meal on Sun Jan 01 CANCELLED")
    end

    it "renders the correct name and URL in the body" do
      expect(mail.body.encoded).to match("Dear #{household.name} Household,")
      expect(mail.body.encoded).to match(/We regret to inform you that .+ CANCELLED/)
      expect(mail.body.encoded).to have_correct_meal_url(meal)
    end
  end
end
