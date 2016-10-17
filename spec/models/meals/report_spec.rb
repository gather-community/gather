require 'rails_helper'

RSpec.describe Meals::Report, type: :model do
  let(:community) { create(:community, abbrv: "C1") }
  let(:community2) { create(:community, abbrv: "C2") }
  let(:cid) { community.id }
  let(:report) { Meals::Report.new(community) }

  before { Timecop.freeze(Time.parse("2016-10-15 12:00:00")) }
  after { Timecop.return }

  describe "range" do
    it "should end on the last full month" do
      Timecop.freeze(Date.civil(2016,3,15)) do
        expect(report.range).to eq Date.civil(2015, 3, 1)..Date.civil(2016, 2, 29)
      end
    end
  end

  describe "diner_types" do
    before do
      meals = create_list(:meal, 2, :finalized, host_community_id: cid, served_at: 2.months.ago)
      meals.each do |m|
        m.signups << build(:signup, meal: m, adult_meat: 1)
        m.signups << build(:signup, meal: m, senior_veg: 1, little_kid_meat: 1)
        m.save!
      end
    end

    it "should return all diner types in results" do
      expect(report.diner_types).to eq %w(senior adult little_kid)
    end
  end

  describe "overview" do
    context "without finalized meals" do
      before do
        create(:meal, host_community_id: cid)
      end

      it "should return nil" do
        expect(report.overview).to be_nil
      end
    end

    context "with finalized meals" do
      before do
        meals = create_list(:meal, 2, :finalized, host_community_id: cid)

        # Very old meal in different community.
        meals << create(:meal, :finalized, host_community_id: community2.id, served_at: 2.years.ago)

        meals.each do |m|
          m.signups << build(:signup, meal: m, adult_meat: 2)
          m.signups << build(:signup, meal: m, adult_veg: 1)
          m.save!
        end
      end

      it "should have correct data" do
        expect(report.overview[cid]["ttl_meals"]).to eq 2
        expect(report.overview[cid]["ttl_diners"]).to eq 6
        expect(report.overview[cid]["ttl_cost"]).to eq 24
        expect(report.overview[:all]["ttl_meals"]).to eq 3
        expect(report.overview[:all]["ttl_diners"]).to eq 9
        expect(report.overview[:all]["ttl_cost"]).to eq 36
      end
    end
  end

  describe "disaggregated" do
    context "without finalized meals" do
      describe "by_month" do
        before do
          create(:meal, host_community_id: cid)
        end

        it "should return nil" do
          expect(report.by_month).to be_nil
        end
      end
    end

    context "with finalized meals" do
      before do
        meals, hholds = [], []
        meals << create(:meal, :finalized, host_community_id: cid, served_at: "2016-01-01 18:00") # Fri
        meals << create(:meal, :finalized, host_community_id: cid, served_at: "2016-02-10 18:00") # Wed
        meals << create(:meal, :finalized, host_community_id: cid, served_at: "2016-02-12 18:00") # Fri
        meals << create(:meal, :finalized, host_community_id: cid, served_at: "2016-04-05 18:00") # Tue
        hholds << create(:household, community: community)
        hholds << create(:household, community: community2)
        counts = [[5, 1], [7, 3], [4, 0], [8, 1]]
        meals.each_with_index do |m, i|
          m.cost.adult_meat = i + 1
          m.signups << build(:signup, meal: m, adult_meat: counts[i][0], household: hholds[0])
          m.signups << build(:signup, meal: m, senior_veg: counts[i][1], household: hholds[1])
          m.save!
        end

        # Very old meal, should be ignored.
        meals << create(:meal, :finalized, host_community_id: cid, served_at: 2.years.ago)
      end

      describe "by_month" do
        it "should have correct data" do
          expect(report.by_month.size).to eq 4
          expect((report.by_month.keys - [:all]).map(&:month)).to eq [1,2,4]

          jan = report.by_month[Date.civil(2016,1,1)]
          feb = report.by_month[Date.civil(2016,2,1)]
          apr = report.by_month[Date.civil(2016,4,1)]
          all = report.by_month[:all]

          expect(jan["ttl_meals"]).to eq 1
          expect(jan["ttl_diners"]).to eq 6
          expect(jan["ttl_cost"]).to eq 12

          expect(feb["ttl_meals"]).to eq 2
          expect(feb["ttl_diners"]).to eq 14
          expect(feb["ttl_cost"]).to eq 24
          expect(feb["avg_adult_cost"]).to eq 2.50
          expect(feb["avg_diners"]).to eq 7.0
          expect(feb["avg_veg"]).to eq 1.5
          expect(feb["avg_veg_pct"]).to be_within(0.1).of 21.4
          expect(feb["avg_adult"]).to eq 5.5
          expect(feb["avg_adult_pct"]).to be_within(0.1).of 78.5
          expect(feb["avg_from_c1"]).to eq 5.5
          expect(feb["avg_from_c1_pct"]).to be_within(0.1).of 78.5
          expect(feb["avg_from_c2"]).to eq 1.5
          expect(feb["avg_from_c2_pct"]).to be_within(0.1).of 21.4

          expect(apr["ttl_meals"]).to eq 1
          expect(apr["ttl_diners"]).to eq 9
          expect(apr["ttl_cost"]).to eq 12
          expect(apr["avg_adult_cost"]).to eq 4.00

          expect(all["ttl_meals"]).to eq 4
          expect(all["ttl_diners"]).to eq 29
          expect(all["ttl_cost"]).to eq 48
          expect(all["avg_adult_cost"]).to eq 2.50
          expect(all["avg_diners"]).to eq 7.25
          expect(all["avg_veg"]).to eq 1.25
          expect(all["avg_veg_pct"]).to be_within(0.1).of 17.2
          expect(all["avg_adult"]).to eq 6
          expect(all["avg_adult_pct"]).to be_within(0.1).of 82.7
        end
      end

      # This method shares most functionality with by_month, so testing it lightly.
      describe "by_weekday" do
        it "should have correct data" do
          expect(report.by_weekday.size).to eq 3
          expect(report.by_weekday.keys.map { |k| k.strftime("%a") }).to eq %w(Tue Wed Fri)
        end
      end
    end
  end
end

