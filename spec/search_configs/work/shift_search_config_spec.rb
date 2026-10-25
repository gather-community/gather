# frozen_string_literal: true

require "rails_helper"

describe Work::ShiftSearchConfig, search: Work::Shift do
  let(:period) { create(:work_period) }
  let(:group) { create(:group, name: "Södergren Friends", can_request_jobs: true) }
  let(:worker) { create(:user, first_name: "Zoë", last_name: "Lefèvre") }

  before do
    create(:work_job, period: period, title: "Café Cleanup")
    create(:work_job, period: period, title: "Garden Help", requester: group)
    create(:work_job, period: period, title: "Cafeteria Setup")
    shift = create(:work_job, period: period, title: "Dishes").shifts.first
    create(:work_assignment, shift: shift, user: worker)
    Work::ShiftIndexUpdater.instance.reindex(Work::Shift.all.to_a) # Picks up the assignment.
    Work::Shift.__elasticsearch__.refresh_index!
  end

  def titles(text)
    Work::Shift.text_search(text).records.map { |shift| shift.job.title }.uniq.sort
  end

  it "matches with or without accents" do
    expect(titles("cafe")).to eq(["Café Cleanup"])
    expect(titles("Café")).to eq(["Café Cleanup"])
    expect(titles("sodergren")).to eq(["Garden Help"])
    expect(titles("Södergren")).to eq(["Garden Help"])
    expect(titles("zoe lefevre")).to eq(["Dishes"])
  end

  it "needs every word to match, across fields" do
    expect(titles("garden sodergren")).to eq(["Garden Help"])
    expect(titles("garden cafe")).to be_empty
  end

  it "matches whole words, not prefixes" do
    expect(titles("cafeteria")).to eq(["Cafeteria Setup"])
    expect(titles("cafet")).to be_empty
  end

  describe "rebuilding the index" do
    it "indexes every shift in every cluster" do
      other_cluster = create(:cluster)
      with_tenant(other_cluster) { create(:work_job, title: "Café Elsewhere") }
      Work::Shift.__elasticsearch__.delete_index!

      count = Work::ShiftIndexUpdater.instance.rebuild_index
      Work::Shift.__elasticsearch__.refresh_index!

      expect(count).to eq(ActsAsTenant.without_tenant { Work::Shift.count })
      expect(Work::Shift.search("*").results.total).to eq(count)
      ActsAsTenant.without_tenant { expect(titles("cafe")).to eq(["Café Cleanup", "Café Elsewhere"]) }
    end
  end
end
