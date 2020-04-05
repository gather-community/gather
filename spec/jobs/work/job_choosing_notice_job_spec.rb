# frozen_string_literal: true

require "rails_helper"

describe Work::JobChoosingNoticeJob do
  include_context "jobs"

  let!(:period) do
    create(:work_period, pick_type: "staggered", quota_type: "by_person", workers_per_round: 3,
                         round_duration: 5, max_rounds_per_worker: 3,
                         auto_open_time: Time.zone.now + 2.months)
  end
  let!(:users) { create_list(:user, 3) }
  let!(:shares) do
    [0, 0.5, 1].each_with_index { |p, i| create(:work_share, user: users[i], period: period, portion: p) }
  end
  let!(:period2) do
    create(:work_period, pick_type: "staggered", quota_type: "by_person", workers_per_round: 3,
                         round_duration: 5, max_rounds_per_worker: 3,
                         auto_open_time: Time.zone.now + 3.months)
  end
  let!(:decoy_shares) do
    [0, 0.5, 1].each_with_index { |p, i| create(:work_share, user: users[i], period: period2, portion: p) }
  end

  it "sends emails to those with nonzero periods" do
    expect(WorkMailer).to receive(:job_choosing_notice).exactly(2).times.and_return(mlrdbl)
    perform_job(period.id)
  end
end
