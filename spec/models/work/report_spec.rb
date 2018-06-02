# frozen_string_literal: true

require "rails_helper"

describe Work::Report do
  let(:period) { create(:work_period, quota_type: quota_type) }
  let(:users) { create_list(:user, 8) }
  subject(:report) { described_class.new(period: period, user: users[0]) }

  before do
    users[1].update!(household: users[0].household)
    users[7].deactivate
  end

  context "with no jobs" do
    let(:quota_type) { "none" }

    it "returns correct values" do
      expect(subject.fixed_slots).to eq(0)
      expect(subject.by_user).to be_empty
      expect(subject.shares).to be_empty
      expect(subject.shares_by_user).to be_empty
      expect(subject.users).to be_empty
      expect(subject.households).to be_empty
      expect(subject.total_portions).to eq(0)
      expect(subject.full_community_jobs).to be_empty
      expect(subject.fixed_slot_hours).to eq(0)
      expect(subject.fixed_slot_non_preassigned_hours).to eq(0)
    end
  end

  context "with lots of jobs" do
    let(:groups) { create_list(:people_group, 2) }
    let(:jobs) do
      [
        create(:work_job, period: period, requester: groups[0],
                          hours: 3.5, shift_count: 2, shift_slots: 1), # 7 hours
        create(:work_job, period: period, requester: groups[0],
                          hours: 1,   shift_count: 2, shift_slots: 3), # 6 hours
        create(:work_job, period: period, requester: groups[1],
                          hours: 4,   shift_count: 1, shift_slots: 2), # 8 hours
        create(:work_job, period: period, requester: nil,
                          hours: 7,   shift_count: 2, shift_slots: 1), # 14 hours
        create(:work_job, period: period, requester: groups[1], slot_type: "full_multiple",
                          hours: 6, hours_per_shift: 3, shift_count: 3)
      ]
    end

    before do
      # Preassigned shifts
      period.update!(phase: "draft")
      jobs[0].shifts[0].assignments.create!(user: users[3])  # 3.5 hours
      jobs[0].shifts[1].assignments.create!(user: users[1])  # 3.5 hours
      jobs[2].shifts[0].assignments.create!(user: users[0])  # 4 hours
      jobs[2].shifts[0].assignments.create!(user: users[2])  # 4 hours

      period.update!(phase: "open")
      jobs[1].shifts[0].assignments.create!(user: users[2]) # 1 hours
      jobs[1].shifts[0].assignments.create!(user: users[0]) # 1 hours
      jobs[1].shifts[0].assignments.create!(user: users[1]) # 1 hours
      jobs[1].shifts[1].assignments.create!(user: users[0]) # 1 hours
      # job 1 shift 1 has 2 unfilled slots
      jobs[3].shifts[0].assignments.create!(user: users[3]) # 7 hours
      # job 3 shift 1 has 1 no assignees (1 unfilled slot)
      jobs[4].shifts[0].assignments.create!(user: users[0]) # 3 hours
      jobs[4].shifts[0].assignments.create!(user: users[2]) # 3 hours
      jobs[4].shifts[0].assignments.create!(user: users[3]) # 3 hours
      jobs[4].shifts[1].assignments.create!(user: users[0]) # 3 hours
      jobs[4].shifts[1].assignments.create!(user: users[3]) # 3 hours
      jobs[4].shifts[2].assignments.create!(user: users[1]) # 3 hours
      # user 2 has only signed up for 1 full community job shift, but is expected to do 2
      # user 5 has not signed up for _any_ jobs even though they have a full share
    end

    context "with quota" do
      let(:quota_type) { "by_household" }

      before do
        period.shares.create!(user: users[0], portion: 1)
        period.shares.create!(user: users[1], portion: 0.5)
        period.shares.create!(user: users[2], portion: 1)
        period.shares.create!(user: users[3], portion: 0)
        period.shares.create!(user: users[4], portion: 0)
        period.shares.create!(user: users[5], portion: 1)
        period.shares.create!(user: users[7], portion: 1) # Inactive user
      end

      it "returns correct values" do
        expect(subject.fixed_slots).to eq(12)

        expect(subject.by_user.size).to eq(4)
        expect(subject.by_user[users[0].id][:preassigned]).to be_within(0.01).of(4)
        expect(subject.by_user[users[0].id][:fixed_slot]).to be_within(0.01).of(6)
        expect(subject.by_user[users[0].id][:total]).to be_within(0.01).of(12)
        expect(subject.by_user[users[0].id][jobs[4]]).to be_within(0.01).of(6)
        expect(subject.by_user[users[0].id].size).to eq(4)
        expect(subject.by_user[users[1].id][:preassigned]).to be_within(0.01).of(3.5)
        expect(subject.by_user[users[1].id][:fixed_slot]).to be_within(0.01).of(4.5)
        expect(subject.by_user[users[1].id][:total]).to be_within(0.01).of(7.5)
        expect(subject.by_user[users[1].id][jobs[4]]).to be_within(0.01).of(3)
        expect(subject.by_user[users[1].id].size).to eq(4)
        expect(subject.by_user[users[2].id][:preassigned]).to be_within(0.01).of(4)
        expect(subject.by_user[users[2].id][:fixed_slot]).to be_within(0.01).of(5)
        expect(subject.by_user[users[2].id][:total]).to be_within(0.01).of(8)
        expect(subject.by_user[users[2].id][jobs[4]]).to be_within(0.01).of(3)
        expect(subject.by_user[users[2].id].size).to eq(4)
        expect(subject.by_user[users[3].id][:preassigned]).to be_within(0.01).of(3.5)
        expect(subject.by_user[users[3].id][:fixed_slot]).to be_within(0.01).of(10.5)
        expect(subject.by_user[users[3].id][:total]).to be_within(0.01).of(16.5)
        expect(subject.by_user[users[3].id][jobs[4]]).to be_within(0.01).of(6)
        expect(subject.by_user[users[3].id].size).to eq(4)

        expect(subject.shares).to match_array(period.shares[0..-2])
        expect(subject.shares_by_user.size).to eq(6)
        6.times { |i| expect(subject.shares_by_user[users[i].id]).to eq(period.shares[i]) }

        # Should omit those with zero or no share and having no hours.
        expected_users = users - [users[4], users[6], users[7]]
        expect(subject.users).to match_array(expected_users)
        expect(subject.households).to match_array(expected_users.map(&:household).uniq)

        expect(subject.total_portions).to eq(3.5)
        expect(subject.full_community_jobs).to eq([jobs[4]])
        expect(subject.fixed_slot_hours).to eq(35)
        expect(subject.fixed_slot_non_preassigned_hours).to eq(20)
      end
    end

    context "without quota" do
      let(:quota_type) { "none" }

      it "returns correct values" do
        expect(subject.shares).to be_empty
        expect(subject.shares_by_user).to be_empty
        expect(subject.total_portions).to be_zero

        # Should omit those with no assignments
        expect(subject.users).to match_array(users[0...4])
      end
    end
  end
end
