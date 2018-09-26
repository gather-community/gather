# frozen_string_literal: true

require "rails_helper"

describe Work::ShiftIndexUpdater do
  let(:updater) { described_class.new(source) }

  describe "job title update" do
    let(:job) { create(:work_job, shift_count: 2) }
    let(:source) { job }

    it "updates shifts on job title change" do
      expect(updater).to receive(:reindex).with(job.shifts)
      job.update!(title: "A new title")
      updater.update
    end

    it "updates shifts on assignment change" do
      expect(updater).to receive(:reindex)
      job.update!(shifts_attributes: {
        0 => {
          id: job.shifts.first.id,
          assignments_attributes: {
            0 => {
              user_id: create(:user).id
            }
          }
        }
      })
      updater.update
    end
  end

  describe "requester name update" do
    let(:group) { create(:people_group) }
    let(:job1) { create(:work_job, shift_count: 2, requester: group) }
    let(:job2) { create(:work_job, shift_count: 3, requester: group) }
    let(:job3) { create(:work_job, shift_count: 1) }
    let(:source) { group }

    it "updates shifts on requester name change" do
      expect(updater).to receive(:reindex).with(job1.shifts)
      expect(updater).to receive(:reindex).with(job2.shifts)
      group.update!(name: "A new name")
      updater.update
    end

    it "doesn't update shifts on requester touch" do
      expect(updater).not_to receive(:reindex)
      group.touch
      updater.update
    end
  end

  describe "user name update" do
    let(:user) { create(:user) }
    let(:job1) { create(:work_job, shift_count: 3) }
    let(:source) { user }

    before do
      job1.shifts[0..1].each { |s| s.assignments.create(user: user) }
    end

    it "updates shifts on user name change" do
      expect(updater).to receive(:reindex).with(job1.shifts[0])
      expect(updater).to receive(:reindex).with(job1.shifts[1])
      user.update!(first_name: "A new name")
      updater.update
    end

    it "doesn't update shifts on user email change" do
      expect(updater).not_to receive(:reindex)
      user.update!(email: "new@example.com")
      updater.update
    end
  end
end
