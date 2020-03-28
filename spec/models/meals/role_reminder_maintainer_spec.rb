# frozen_string_literal: true

require "rails_helper"

describe Meals::RoleReminderMaintainer do
  include_context "reminders"

  let(:yr_mo) { (Time.zone.today + 60).strftime("%Y-%m") }
  let!(:hc_role) { create(:meal_role, :head_cook, time_type: "date_time", shift_start: -70, shift_end: 0) }
  let!(:ac_role) { create(:meal_role, title: "Asst", time_type: "date_time", shift_start: -90, shift_end: 0) }
  let!(:decoy) { create(:meal_role) }
  let!(:formula) { create(:meal_formula, roles: [hc_role, ac_role]) }
  let(:meal) { create(:meal, formula: formula, served_at: "#{yr_mo}-04 12:00") }
  let!(:cancelled_decoy) { create(:meal, :cancelled, formula: formula, served_at: "#{yr_mo}-05 12:00") }
  let(:hc_reminder) { create_meal_role_reminder(hc_role, 2.5, "hours_before") }
  let(:ac_reminder1) { create_meal_role_reminder(ac_role, 2, "hours_before") }
  let(:ac_reminder2) { create_meal_role_reminder(ac_role, 2, "days_before") }

  subject(:deliveries) { Meals::RoleReminderDelivery.all.to_a }
  let(:hc_delivery) { deliveries.detect { |d| d.reminder == hc_reminder } }
  let(:ac_delivery1) { deliveries.detect { |d| d.reminder == ac_reminder1 } }

  shared_examples_for "creates correct deliveries" do
    it do
      expect(deliveries.map(&:reminder)).to contain_exactly(hc_reminder, ac_reminder1, ac_reminder2)
      expect(deliveries.map(&:meal)).to contain_exactly(meal, meal, meal)
      expect(hc_delivery.deliver_at.iso8601).to eq("#{yr_mo}-04T08:20:00Z")
    end
  end

  context "with reminders created first" do
    # We create reminders first so that the deliveries aren't created on reminder creation.
    # This way we know they were created by Meal instead.
    before { hc_reminder && ac_reminder1 && ac_reminder2 && meal }

    context "on new meal creation" do
      it_behaves_like "creates correct deliveries"
    end

    context "on meal time change" do
      before do
        meal.update!(served_at: "#{yr_mo}-05 13:00")
      end

      it "updates delivery" do
        expect(deliveries.size).to eq(3)
        expect(hc_delivery.deliver_at.iso8601).to eq("#{yr_mo}-05T09:20:00Z")
      end
    end

    context "on meal cancel" do
      before do
        meal.cancel!
      end

      it "destroys deliveries" do
        expect(deliveries.size).to eq(0)
      end
    end

    context "on role added to formula" do
      let(:silly_role) { create(:meal_role) }
      let(:silly_reminder) { create_meal_role_reminder(silly_role, 1, "days_before") }

      context "with recent meal" do
        it "creates delivery for new role" do
          silly_reminder
          formula.update!(role_ids: formula.role_ids << silly_role.id)
          expect(deliveries.map(&:reminder)).to contain_exactly(hc_reminder, ac_reminder1,
                                                                ac_reminder2, silly_reminder)
        end
      end

      context "with old meal" do
        it "doesn't create delivery for new role" do
          # This reminder gets created and added to role about 200 days after other reminders and meal.
          Timecop.freeze(200.days) do
            silly_reminder
            formula.update!(role_ids: formula.role_ids << silly_role.id)
            expect(deliveries.map(&:reminder)).to contain_exactly(hc_reminder, ac_reminder1, ac_reminder2)
          end
        end
      end
    end

    context "on role removed from formula followed by meal time change" do
      before do
        formula.roles.delete(ac_role)
        meal.update!(served_at: "#{yr_mo}-05 13:00")
      end

      it "updates ac delivery even though role removed" do
        expect(deliveries.size).to eq(3)
        expect(ac_delivery1.deliver_at.iso8601).to eq("#{yr_mo}-05T09:30:00Z")
      end
    end

    context "on role attrib change" do
      before do
        ac_role.update!(shift_start: -100)
      end

      it "updates delivery" do
        expect(deliveries.size).to eq(3)
        expect(ac_delivery1.deliver_at.iso8601).to eq("#{yr_mo}-04T08:20:00Z")
      end
    end
  end

  context "with meal created first" do
    before { meal && hc_reminder && ac_reminder1 && ac_reminder2 }

    context "on reminder creation" do
      # We test the same thing down here as above, but since the meal was created first, we know that
      # if it passes, the reminders must have caused the delivery creation, not the meal.
      it_behaves_like "creates correct deliveries"
    end

    context "on reminder attrib change" do
      before do
        hc_reminder.update!(rel_magnitude: 1)
      end

      it "updates delivery" do
        expect(deliveries.size).to eq(3)
        expect(hc_delivery.deliver_at.iso8601).to eq("#{yr_mo}-04T09:50:00Z")
      end
    end
  end
end
