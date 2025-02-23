# frozen_string_literal: true

require "rails_helper"

describe Meals::EventHandler do
  let(:community) { Defaults.community }
  let(:calendars) { create_list(:calendar, 2) }
  let(:meal) do
    build(:meal, :with_menu, community: community, title: "A very very very long title",
                             calendars: calendars, served_at: "2017-01-01 12:00")
  end
  let(:handler) { described_class.new(meal) }
  let(:handler2) { described_class.new(meal) }

  before do
    community.settings.calendars.meals.default_prep_time = 90
    community.settings.calendars.meals.default_total_time = 210
    community.save!
  end

  describe "build_events" do
    describe "on create" do
      before do
        # Set custom times for second resourcing.
        meal.resourcings[1].prep_time = 60
        meal.resourcings[1].total_time = 90
        handler.build_events
      end

      context "with clear calendars" do
        it "should initialize events on both calendars" do
          events = meal.events
          expect(events.map(&:calendar)).to contain_exactly(*calendars)
          expect(events.map(&:starts_at)).to eq([
            Time.zone.parse("2017-01-01 10:30"),
            Time.zone.parse("2017-01-01 11:00")
          ])
          expect(events.map(&:ends_at)).to eq([
            Time.zone.parse("2017-01-01 14:00"),
            Time.zone.parse("2017-01-01 12:30")
          ])
          expect(events.map(&:kind).uniq).to eq(["_meal"])
          expect(events.map(&:guidelines_ok).uniq).to eq(["1"])
          expect(events.map(&:creator).uniq).to eq([nil])
          expect(events[0].name).to eq("Meal: A very very ver...")
        end
      end
    end

    context "on update" do
      before do
        meal.build_events
        meal.save!
      end

      context "on calendar change" do
        let(:calendar2) { create(:calendar) }

        it "should update event" do
          meal.calendars = [calendar2]
          handler.build_events
          meal.save!
          expect(meal.events.reload.first.calendar).to eq(calendar2)
          expect(meal.events.size).to eq(1)
        end

        it "should handle validation errors" do
          # Create event that will conflict when meal calendar changes
          meal_time = meal.served_at
          create(:event, calendar: calendar2,
                         starts_at: meal_time, ends_at: meal_time + 30.minutes)

          meal.calendars = [calendar2]
          handler.build_events
          meal.save
          expect_overlap_error(calendar2)
        end
      end

      context "on title change" do
        before do
          meal.events.first.update!(note: "Foo")
        end

        it "should update event and preserve unaffected fields" do
          meal.title = "Nosh time"
          handler.build_events
          meal.save!
          expect(meal.events.reload.first.name).to eq("Meal: Nosh time")
          expect(meal.events.first.note).to eq("Foo")
        end
      end

      context "on time change" do
        context "with no conflict" do
          before do
            meal.update(served_at: "2017-01-01 13:00")
            described_class.new(meal).build_events
            meal.save!
          end

          it "should delete and replace previous events" do
            expect(Calendars::Event.count).to eq(2)
            expect(meal.events.map(&:starts_at)).to eq([
              Time.zone.parse("2017-01-01 10:30"),
              Time.zone.parse("2017-01-01 10:30")
            ])
          end
        end

        context "with conflict" do
          before do
            new_meal_time = meal.served_at + 1.day
            create(:event, calendar: calendars[1],
                           starts_at: new_meal_time, ends_at: new_meal_time + 30.minutes)
            meal.served_at = new_meal_time
            handler.build_events
          end

          it "should handle validation errors" do
            expect(meal).not_to be_valid
            p meal.calendars.map(&:errors)
            expect_overlap_error(calendars[1])
          end
        end
      end

      context "with no meal time or title change or calendar change" do
        let!(:new_time) { Time.zone.parse("2017-01-01 10:40") }

        before do
          # Perturb to non-default time so we can test that events are not rebuilt.
          meal.events[0].update!(starts_at: new_time)
        end

        it "should not rebuild events" do
          meal.capacity += 1
          handler.build_events
          meal.save!
          expect(meal.events[0].reload.starts_at).to eq(new_time)
        end
      end
    end
  end

  describe "validate_meal" do
    let!(:conflicting_event) do
      create(:event, calendar: calendars[0],
                     starts_at: "2017-01-01 11:00", ends_at: "2017-01-01 12:00")
    end

    before do
      handler.build_events
      handler.validate_meal
    end

    it "sets base error on meal" do
      expect_overlap_error(calendars[0])
    end
  end

  describe "validate_event" do
    let(:event) { meal.reload.events[0] }

    before do
      handler.build_events
      meal.save!
    end

    context "with valid change" do
      before do
        event.starts_at += 30.minutes
        event.ends_at += 15.minutes
        handler2.validate_event(event)
      end

      it "should not set error" do
        expect(event.errors.any?).to be(false)
      end
    end

    context "with change that moves start time after served_at" do
      before do
        event.starts_at = meal.served_at + 15.minutes
        handler2.validate_event(event)
      end

      it "should set error" do
        expect(event.errors[:starts_at]).to eq(["must be at or before the meal time (12:00pm)"])
        expect(event.errors[:ends_at]).to eq([])
      end
    end

    context "with change that moves end time before served_at" do
      before do
        event.ends_at = meal.served_at - 15.minutes
        handler2.validate_event(event)
      end

      it "should set error" do
        expect(event.errors[:starts_at]).to eq([])
        expect(event.errors[:ends_at]).to eq(["must be after the meal time (12:00pm)"])
      end
    end

    context "with event with nil starts_at" do
      it "should not error" do
        event.starts_at = nil
        handler2.validate_event(event)
      end
    end

    context "with event with nil ends_at" do
      it "should not error" do
        event.ends_at = nil
        handler2.validate_event(event)
      end
    end

    context "with meal with nil served_at" do
      it "should not error" do
        meal.served_at = nil
        handler2.validate_event(event)
      end
    end
  end

  describe "sync_resourcings" do
    let(:event) { meal.reload.events[0] }

    before do
      handler.build_events
      meal.save!
      event.starts_at += 30.minutes
      event.ends_at += 15.minutes
      handler2.sync_resourcings(event)
    end

    it "should change the resourcing's prep time and total time" do
      rsng = meal.resourcings[0].reload
      expect(rsng.prep_time).to eq(60)
      expect(rsng.total_time).to eq(195)
    end
  end

  def expect_overlap_error(calendar)
    expect(meal).not_to be_valid
    expect(meal.errors[:base]).to eq(["The following error(s) occurred in making a #{calendar.name} " \
                                      "event for this meal: This event overlaps an existing one."])
  end
end
