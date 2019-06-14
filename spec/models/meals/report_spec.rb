# frozen_string_literal: true

require "rails_helper"

describe(Meals::Report) do
  let!(:community) { create(:community, name: "Community 1", abbrv: "C1") }
  let!(:community2) { create(:community, name: "Community 2", abbrv: "C2") }
  let!(:communityX) { with_tenant(create(:cluster)) { create(:community, name: "Community X", abbrv: "CX") } }
  let(:range) { nil }
  let!(:report) { Meals::Report.new(community, range: range) }

  around do |example|
    Timecop.freeze(Time.zone.parse("2016-10-15 12:00:00")) do
      example.run
    end
  end

  describe "default_range" do
    context "with no meals" do
      it "should end on the last full month" do
        expect(report.send(:default_range)).to eq(Date.new(2015, 10, 1)..Date.new(2016, 9, 30))
      end
    end

    context "with previous month having unfinalized meals" do
      before do
        create(:meal, :finalized, community: community, served_at: "2016-08-15 17:00")
        create(:meal, community: community, served_at: "2016-09-15 17:00")
      end

      it "should end on month before previous month" do
        expect(report.send(:default_range)).to eq(Date.new(2015, 9, 1)..Date.new(2016, 8, 31))
      end
    end

    context "with previous month having all finalized meals" do
      before do
        create(:meal, :finalized, community: community, served_at: "2016-08-15 17:00")
        create(:meal, :finalized, community: community, served_at: "2016-09-15 17:00")
      end

      it "should end on month before previous month" do
        expect(report.send(:default_range)).to eq(Date.new(2015, 10, 1)..Date.new(2016, 9, 30))
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
      expect(report.diner_types).to eq(%w[adult senior little_kid])
    end
  end

  describe "#empty?" do
    context "without finalized meals" do
      before do
        create(:meal, community: community)
      end

      it "should be empty" do
        expect(report).to be_empty
      end
    end

    context "with only finalized meals not in range" do
      before do
        meals = create_list(:meal, 2, :finalized, community: community, served_at: 1.day.ago)
        meals.each do |m|
          m.signups << build(:signup, meal: m, adult_meat: 2)
          m.signups << build(:signup, meal: m, adult_veg: 1)
          m.save!
        end

        # The report range won't include these meals because one is unfinalized and they're on the same day.
        create(:meal, community: community, served_at: 1.day.ago)
      end

      it "should be empty" do
        expect(report).to be_empty
      end
    end
  end

  describe "overview" do
    context "with finalized meals" do
      before do
        meals = []
        meals << create(:meal, :finalized, community: community, served_at: 1.month.ago)
        meals << create(:meal, :finalized, community: community, served_at: 6.months.ago)

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
        expect(report.overview[community.id]["ttl_meals"]).to eq(2)
        expect(report.overview[community.id]["ttl_diners"]).to eq(6)
        expect(report.overview[community.id]["ttl_cost"]).to eq(24)
        expect(report.overview[:all]["ttl_meals"]).to eq(3)
        expect(report.overview[:all]["ttl_diners"]).to eq(9)
        expect(report.overview[:all]["ttl_cost"]).to eq(36)
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
        meals = []
        hholds = []
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

        # Cancelled meal, should be ignored.
        m = create(:meal, :cancelled, community: community, served_at: "2016-04-12 18:00")
        m.signups << build(:signup, meal: m, adult_meat: 2, household: hholds[0])
        m.signups << build(:signup, meal: m, senior_veg: 2, household: hholds[1])
        m.save!

        # Cancelled meal in other community, should be ignored.
        m = create(:meal, :cancelled, community: community2, served_at: "2016-04-12 18:00")
        m.signups << build(:signup, meal: m, adult_meat: 2, household: hholds[0])
        m.signups << build(:signup, meal: m, senior_veg: 2, household: hholds[1])
        m.save!

        # Very old meal, should be ignored.
        create(:meal, :finalized, community: community, served_at: 2.years.ago)

        # Meals from community 2 and X
        meals2 = create_list(:meal, 2, :finalized, community: community2, served_at: 2.months.ago)
        meals2.each do |meal|
          meal.signups << build(:signup, meal: meal, adult_meat: 2)
          meal.save!
        end
        meal3 = create(:meal, :finalized, community: communityX, served_at: 2.months.ago)
        meal3.signups << build(:signup, meal: meal3, adult_meat: 2)
        meal3.save!
      end

      describe "by_month" do
        it "should have correct data" do
          expect(report.by_month.size).to eq(4)
          expect((report.by_month.keys - [:all]).map(&:month)).to eq([1, 2, 4])

          jan = report.by_month[Date.new(2016, 1, 1)]
          feb = report.by_month[Date.new(2016, 2, 1)]
          mar = report.by_month[Date.new(2016, 3, 1)]
          apr = report.by_month[Date.new(2016, 4, 1)]
          all = report.by_month[:all]

          expect(jan["ttl_meals"]).to eq(1)
          expect(jan["ttl_diners"]).to eq(6)
          expect(jan["ttl_cost"]).to eq(12)

          expect(feb["ttl_meals"]).to eq(2)
          expect(feb["ttl_diners"]).to eq(16)
          expect(feb["ttl_cost"]).to eq(24)
          expect(feb["avg_adult_cost"]).to eq(2.50)
          expect(feb["avg_diners"]).to eq(8.0)
          expect(feb["avg_adult"]).to eq(5.5)
          expect(feb["avg_adult_pct"]).to be_within(0.1).of(68.75)
          expect(feb["avg_from_#{community.id}"]).to eq(5.5)
          expect(feb["avg_from_#{community.id}_pct"]).to be_within(0.1).of(68.75)
          expect(feb["avg_from_#{community2.id}"]).to eq(2.5)
          expect(feb["avg_from_#{community2.id}_pct"]).to be_within(0.1).of(31.25)

          expect(mar).to be_nil

          expect(apr["ttl_meals"]).to eq(1)
          expect(apr["ttl_diners"]).to eq(9)
          expect(apr["ttl_cost"]).to eq(12)
          expect(apr["avg_adult_cost"]).to eq(4.00)

          expect(all["ttl_meals"]).to eq(4)
          expect(all["ttl_diners"]).to eq(31)
          expect(all["ttl_cost"]).to eq(48)
          expect(all["avg_adult_cost"]).to eq(2.50)
          expect(all["avg_diners"]).to eq(7.75)
          expect(all["avg_adult"]).to eq(6)
          expect(all["avg_adult_pct"]).to be_within(0.1).of(77.4)
        end

        context "with explicit range" do
          let(:range) { (Date.new(2016, 1, 1))..(Date.new(2016, 3, 1)) }

          it "should have correct data from specific range" do
            expect(report.by_month[:all]["ttl_meals"]).to eq(3)
          end
        end

        describe "cancelled" do
          it "should count cancelled meals in current community only" do
            expect(report.cancelled).to eq(1)
          end
        end
      end

      describe "by_month_no_totals_or_gaps" do
        it "should have correct data" do
          expect(report.by_month_no_totals_or_gaps.size).to eq(4)
          expect(report.by_month_no_totals_or_gaps.keys.map(&:month)).to eq([1, 2, 3, 4])
          expect(report.by_month_no_totals_or_gaps[Date.new(2016, 3, 1)]).to eq({})
        end
      end

      # This method shares most functionality with by_month, so testing it lightly.
      describe "by_weekday" do
        it "should have correct data" do
          expect(report.by_weekday.size).to eq(3)
          expect(report.by_weekday.keys.map { |k| k.strftime("%a") }).to eq(%w[Tue Wed Fri])
        end
      end

      # This method shares most functionality with by_month, so testing it lightly.
      describe "by_community" do
        it "should have correct data" do
          expect(report.by_community.size).to eq(2)
          expect(report.by_community.keys).to eq(["Community 1", "Community 2"])
        end
      end
    end
  end
end
