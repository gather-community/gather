# frozen_string_literal: true

describe Work::Report do
  let(:period) { create(:work_period) }
  let(:users) { create_list(:user, 6) }

  before do
    users[1].update!(household: users[0].household)
  end

  context "with no jobs" do

  end

  context "with lots of jobs" do
    let(:groups) { create_list(:people_groups, 2) }
    let(:jobs) do
      [
        create(:work_job, requester: groups[0], hours: 3.5, shift_count: 2, shift_slots: 1), # 7 hours
        create(:work_job, requester: groups[0], hours: 1,   shift_count: 2, shift_slots: 3), # 6 hours
        create(:work_job, requester: groups[1], hours: 4,   shift_count: 1, shift_slots: 2), # 8 hours
        create(:work_job, requester: nil,       hours: 7,   shift_count: 2, shift_slots: 1), # 14 hours
        create(:work_job, requester: groups[1], slot_type: "full_multiple",
                          hours: 6, hours_per_shift: 3, shift_count: 3)
      ]
    end

    before do
      jobs[0].shifts[0].assignments.create!(user: users[3], preassigned: true)  # 3.5 hours
      jobs[0].shifts[1].assignments.create!(user: users[1], preassigned: true)  # 3.5 hours
      jobs[1].shifts[0].assignments.create!(user: users[2], preassigned: false) # 1 hours
      jobs[1].shifts[0].assignments.create!(user: users[0], preassigned: false) # 1 hours
      jobs[1].shifts[0].assignments.create!(user: users[1], preassigned: false) # 1 hours
      jobs[1].shifts[1].assignments.create!(user: users[0], preassigned: false) # 1 hours
      # job 1 shift 1 has 2 unfilled slots
      jobs[2].shifts[0].assignments.create!(user: users[0], preassigned: true)  # 4 hours
      jobs[2].shifts[0].assignments.create!(user: users[2], preassigned: true)  # 4 hours
      jobs[3].shifts[0].assignments.create!(user: users[3], preassigned: false) # 7 hours
      # job 3 shift 1 has 1 no assignees (1 unfilled slot)
      jobs[4].shifts[0].assignments.create!(user: users[0], preassigned: false) # 3 hours
      jobs[4].shifts[0].assignments.create!(user: users[2], preassigned: false) # 3 hours
      jobs[4].shifts[0].assignments.create!(user: users[3], preassigned: false) # 3 hours
      jobs[4].shifts[1].assignments.create!(user: users[0], preassigned: false) # 3 hours
      jobs[4].shifts[1].assignments.create!(user: users[3], preassigned: false) # 3 hours
      jobs[4].shifts[2].assignments.create!(user: users[1], preassigned: false) # 3 hours
      # user 2 has only signed up for 1 full community job shift, but is expected to do 2
      # user 5 has not signed up for _any_ jobs even though they have a full share
    end

    context "with quota" do
      before do
        period.update!(quota_type: "by_household")
        period.shares.create!(user: users[0], portion: 1)
        period.shares.create!(user: users[1], portion: 0.5)
        period.shares.create!(user: users[2], portion: 1)
        period.shares.create!(user: users[3], portion: 1)
        period.shares.create!(user: users[4], portion: 0)
        period.shares.create!(user: users[5], portion: 1)
      end

      it "returns correct values" do
        expect(subject.regular_hours).to be_within(0.01).of(35)
        expect(subject.unassigned_regular_hours).to be_within(0.01).of(9)
        expect(subject.regular_slots).to eq(12)
        expect(subject.preassigned_hours).to be_within(0.01).of(15)
        expect(subject.user_regular_hours).to be_within(0.01).of(6)
        expect(subject.household_regular_hours).to be_within(0.01).of(10.5)
        expect(subject.participants).to eq(4)
        expect(subject.full_community_actual_hours).to be_within(0.01).of(18)


        expect(subject.full_community_expected_hours).to be_within(0.01).of(27) # 4.5 shares * 6 job hours
        expect()

      end
    end

    context "without quota" do

    end
  end
end
