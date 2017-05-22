require 'rails_helper'

RSpec.describe Meals::Report, type: :model do
  let!(:community) { create(:community, name: "Community 1", abbrv: "C1") }
  let!(:community2) { create(:community, name: "Community 2", abbrv: "C2") }
  let!(:communityX) { with_tenant(create(:cluster)) { create(:community, name: "Community X", abbrv: "CX") } }
  let!(:report) { Meals::Report.new(community) }

  before { Timecop.freeze(Time.parse("2016-10-15 12:00:00")) }
  after { Timecop.return }

  describe "range" do
    context "with no meals" do
      it "should end on the last full month" do
        expect(report.range).to eq Date.new(2015, 10, 1)..Date.new(2016, 9, 30)
      end
    end

    context "with previous month having unfinalized meals" do
      before do
        create(:meal, :finalized, community: community, served_at: "2016-08-15 17:00")
        create(:meal, community: community, served_at: "2016-09-15 17:00")
      end

      it "should end on month before previous month" do
        expect(report.range).to eq Date.new(2015, 9, 1)..Date.new(2016, 8, 31)
      end
    end

    context "with previous month having all finalized meals" do
      before do
        create(:meal, :finalized, community: community, served_at: "2016-08-15 17:00")
        create(:meal, :finalized, community: community, served_at: "2016-09-15 17:00")
      end

      it "should end on month before previous month" do
        expect(report.range).to eq Date.new(2015, 10, 1)..Date.new(2016, 9, 30)
      end
    end
  end

  describe "diner_types" do
    before do
      meals = create_list(:meal, 2, :finalized, community: community, served_at: 2.months.ago)
      meals.each do |m|
        m.signups << build(:signup, meal: m, adult_meat: 1)
        m.signups << build(:signup, meal: m, senior_veg: 1, little_kid_meat: 1)
        m.save!
      end
    end

    it "should return all diner types in results" do
      expect(report.diner_types).to eq %w(adult senior little_kid)
    end
  end

  describe "overview" do
    context "without finalized meals" do
      before do
        create(:meal, community: community)
      end

      it "should return nil" do
        expect(report.overview).to be_nil
      end
    end

    context "with finalized meals" do
      before do
        meals = create_list(:meal, 2, :finalized, community: community)

        # Very old meal in different community.
        meals << create(:meal, :finalized, community: community2, served_at: 2.years.ago)

        # Meal in communityX. Should not show in results.
        meals << create(:meal, :finalized, community: communityX)

        meals.each do |m|
          m.signups << build(:signup, meal: m, adult_meat: 2)
          m.signups << build(:signup, meal: m, adult_veg: 1)
          m.save!
        end
      end

      it "should have correct data from cluster" do
        expect(report.overview[community.id]["ttl_meals"]).to eq 2
        expect(report.overview[community.id]["ttl_diners"]).to eq 6
        expect(report.overview[community.id]["ttl_cost"]).to eq 24
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
          create(:meal, community: community)
        end

        it "should return nil" do
          expect(report.by_month).to be_nil
        end
      end
    end

    context "with finalized meals" do
      before do
        meals, hholds = [], []
        meals << create(:meal, :finalized, community: community, served_at: "2016-01-01 18:00") # Fri
        meals << create(:meal, :finalized, community: community, served_at: "2016-02-10 18:00") # Wed
        meals << create(:meal, :finalized, community: community, served_at: "2016-02-12 18:00") # Fri
        meals << create(:meal, :finalized, community: community, served_at: "2016-04-05 18:00") # Tue
        hholds << create(:household, community: community)
        hholds << create(:household, community: community2)
        counts = [[5, 1], [7, 3], [4, 2], [8, 1]]
        meals.each_with_index do |m, i|
          m.cost.adult_meat = i + 1
          m.signups << build(:signup, meal: m, adult_meat: counts[i][0], household: hholds[0])
          m.signups << build(:signup, meal: m, senior_veg: counts[i][1], household: hholds[1])
          m.save!
        end

        # Very old meal, should be ignored.
        meals << create(:meal, :finalized, community: community, served_at: 2.years.ago)

        # Meals from community 2 and X
        meals2 = create_list(:meal, 2, :finalized, community: community2, served_at: 2.months.ago)
        meals2.each do |m|
          m.signups << build(:signup, meal: m, adult_meat: 2)
          m.save!
        end
        mealX = create(:meal, :finalized, community: communityX, served_at: 2.months.ago)
        mealX.signups << build(:signup, meal: mealX, adult_meat: 2)
        mealX.save!
      end

      describe "by_month" do
        it "should have correct data" do
          expect(report.by_month.size).to eq 4
          expect((report.by_month.keys - [:all]).map(&:month)).to eq [1,2,4]

          jan = report.by_month[Date.new(2016,1,1)]
          feb = report.by_month[Date.new(2016,2,1)]
          mar = report.by_month[Date.new(2016,3,1)]
          apr = report.by_month[Date.new(2016,4,1)]
          all = report.by_month[:all]

          expect(jan["ttl_meals"]).to eq 1
          expect(jan["ttl_diners"]).to eq 6
          expect(jan["ttl_cost"]).to eq 12

          expect(feb["ttl_meals"]).to eq 2
          expect(feb["ttl_diners"]).to eq 16
          expect(feb["ttl_cost"]).to eq 24
          expect(feb["avg_adult_cost"]).to eq 2.50
          expect(feb["avg_diners"]).to eq 8.0
          expect(feb["avg_veg"]).to eq 2.5
          expect(feb["avg_veg_pct"]).to be_within(0.1).of 31.25
          expect(feb["avg_adult"]).to eq 5.5
          expect(feb["avg_adult_pct"]).to be_within(0.1).of 68.75
          expect(feb["avg_from_c1"]).to eq 5.5
          expect(feb["avg_from_c1_pct"]).to be_within(0.1).of 68.75
          expect(feb["avg_from_c2"]).to eq 2.5
          expect(feb["avg_from_c2_pct"]).to be_within(0.1).of 31.25

          expect(mar).to be_nil

          expect(apr["ttl_meals"]).to eq 1
          expect(apr["ttl_diners"]).to eq 9
          expect(apr["ttl_cost"]).to eq 12
          expect(apr["avg_adult_cost"]).to eq 4.00

          expect(all["ttl_meals"]).to eq 4
          expect(all["ttl_diners"]).to eq 31
          expect(all["ttl_cost"]).to eq 48
          expect(all["avg_adult_cost"]).to eq 2.50
          expect(all["avg_diners"]).to eq 7.75
          expect(all["avg_veg"]).to eq 1.75
          expect(all["avg_veg_pct"]).to be_within(0.1).of 22.58
          expect(all["avg_adult"]).to eq 6
          expect(all["avg_adult_pct"]).to be_within(0.1).of 77.4
        end
      end

      describe "by_month_no_totals_or_gaps" do
        it "should have correct data" do
          expect(report.by_month_no_totals_or_gaps.size).to eq 4
          expect(report.by_month_no_totals_or_gaps.keys.map(&:month)).to eq [1,2,3,4]
          expect(report.by_month_no_totals_or_gaps[Date.new(2016,3,1)]).to eq({})
        end
      end

      # This method shares most functionality with by_month, so testing it lightly.
      describe "by_weekday" do
        it "should have correct data" do
          expect(report.by_weekday.size).to eq 3
          expect(report.by_weekday.keys.map { |k| k.strftime("%a") }).to eq %w(Tue Wed Fri)
        end
      end

      # This method shares most functionality with by_month, so testing it lightly.
      describe "by_community" do
        it "should have correct data" do
          expect(report.by_community.size).to eq 2
          expect(report.by_community.keys).to eq ["Community 1", "Community 2"]
        end
      end
    end
  end
end
