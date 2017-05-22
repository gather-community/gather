require 'rails_helper'

class SomeReminderJob < ReminderJob
  def self.do_stuff(community)
  end

  def perform
    each_community_at_correct_hour do |community|
      self.class.do_stuff(community)
    end
  end
end

describe SomeReminderJob do
  include_context "jobs"
  include_context "reminder jobs"

  let(:cmty1) { create(:community) } # Defaults to UTC
  let(:cmty2) { create(:community) }

  before do
    cmty2.settings.time_zone = "Newfoundland"
    cmty2.save!
  end

  context "at correct hour for cmty1" do
    it "does stuff for cmty1 only" do
      Timecop.freeze(Time.zone.parse("2017-01-01 00:00 UTC") + Settings.reminders.time_of_day.hours) do
        expect(SomeReminderJob).to receive(:do_stuff).exactly(1).times.with(cmty1)
        perform_job
      end
    end
  end

  context "at correct hour for cmty2" do
    it "does stuff for cmty2 only" do
      Timecop.freeze(Time.zone.parse("2017-01-01 00:00 -0330") + Settings.reminders.time_of_day.hours) do
        expect(SomeReminderJob).to receive(:do_stuff).exactly(1).times.with(cmty2)
        perform_job
      end
    end
  end
end
