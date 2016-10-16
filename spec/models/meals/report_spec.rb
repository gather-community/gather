require 'rails_helper'

RSpec.describe Meals::Report, type: :model do
  let(:community) { create(:community) }
  let(:cid) { community.id }
  let(:report) { Meals::Report.new(community) }

  describe "range" do
    it "should end on the last full month" do
      Timecop.freeze(Date.civil(2016,3,15)) do
        expect(report.range).to eq Date.civil(2015, 3, 1)..Date.civil(2016, 2, 29)
      end
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
        meals << create(:meal, :finalized, host_community_id: create(:community).id)
        meals.each do |m|
          m.signups << build(:signup, meal: m, adult_meat: 2)
          m.signups << build(:signup, meal: m, adult_veg: 1)
          m.save!
        end
      end

      it "should have correct data" do
        expect(report.overview[cid]["ttl_meals"]).to eq 2
        expect(report.overview[cid]["ttl_attendees"]).to eq 6
        expect(report.overview[cid]["ttl_cost"]).to eq 24
        expect(report.overview[:all]["ttl_meals"]).to eq 3
        expect(report.overview[:all]["ttl_attendees"]).to eq 9
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
        meals = []
        meals << create(:meal, :finalized, host_community_id: cid, served_at: "2016-01-01 18:00") # Fri
        meals << create(:meal, :finalized, host_community_id: cid, served_at: "2016-02-10 18:00") # Wed
        meals << create(:meal, :finalized, host_community_id: cid, served_at: "2016-02-12 18:00") # Fri
        meals << create(:meal, :finalized, host_community_id: cid, served_at: "2016-04-05 18:00") # Tue
        meals.each do |m|
          m.signups << build(:signup, meal: m, adult_meat: 2)
          m.signups << build(:signup, meal: m, senior_veg: 1)
          m.save!
        end
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
          expect(jan["ttl_attendees"]).to eq 3
          expect(jan["ttl_cost"]).to eq 12

          expect(feb["ttl_meals"]).to eq 2
          expect(feb["ttl_attendees"]).to eq 6
          expect(feb["ttl_cost"]).to eq 24
          expect(feb["avg_adult_cost"]).to eq 3.56
          expect(feb["avg_attendees"]).to eq 3
          expect(feb["avg_veg"]).to eq 1
          expect(feb["avg_veg_pct"]).to be_within(0.01).of 0.333
          expect(feb["avg_adult_pct"]).to be_within(0.01).of 0.666

          expect(apr["ttl_meals"]).to eq 1
          expect(apr["ttl_attendees"]).to eq 3
          expect(apr["ttl_cost"]).to eq 12

          expect(all["ttl_meals"]).to eq 4
          expect(all["ttl_attendees"]).to eq 12
          expect(all["ttl_cost"]).to eq 48
        end
      end

      # This method shares most functionality with by_month, so testing it lightly.
      describe "by_weekday" do
        it "should have correct data" do
          expect(report.by_weekday.size).to eq 4
          expect((report.by_weekday.keys - [:all]).map { |k| k.strftime("%a") }).to eq %w(Tue Wed Fri)
        end
      end
    end
  end
end

