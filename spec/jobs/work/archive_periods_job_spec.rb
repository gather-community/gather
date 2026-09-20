# frozen_string_literal: true

require "rails_helper"

describe Work::ArchivePeriodsJob do
  include_context "jobs"

  let!(:old_open) do
    create(:work_period, phase: "open", starts_on: Time.zone.today - 90, ends_on: Time.zone.today - 31)
  end
  let!(:recent_open) do
    create(:work_period, phase: "open", starts_on: Time.zone.today - 40, ends_on: Time.zone.today - 10)
  end
  let!(:old_archived) do
    create(:work_period, phase: "archived", starts_on: Time.zone.today - 90, ends_on: Time.zone.today - 31)
  end

  it "archives only periods that ended more than 30 days ago" do
    perform_job
    expect(old_open.reload.phase).to eq("archived")
    expect(recent_open.reload.phase).to eq("open")
    expect(old_archived.reload.phase).to eq("archived")
  end
end
