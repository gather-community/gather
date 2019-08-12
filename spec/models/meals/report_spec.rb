# frozen_string_literal: true

require "rails_helper"

describe(Meals::Report) do
  let!(:community) { create(:community, name: "Community 1", abbrv: "C1") }
  let!(:community2) { create(:community, name: "Community 2", abbrv: "C2") }
  let!(:communityX) { with_tenant(create(:cluster)) { create(:community, name: "Community X", abbrv: "CX") } }
  let(:range) { nil }
  let(:formula) do
    create(:meal_formula, parts_attrs: [
      {type: "Adult", share: "100%", portion: 1},
      {type: "Teen", share: "75%", portion: 0.75},
      {type: "Kid", share: "50%", portion: 0.5},
      {type: "Little Kid", share: "0%", portion: 0.25}
    ])
  end
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
        create(:meal, :finalized, formula: formula, community: community, served_at: "2016-08-15 17:00")
        create(:meal, formula: formula, community: community, served_at: "2016-09-15 17:00")
      end

      it "should end on month before previous month" do
        expect(report.send(:default_range)).to eq(Date.new(2015, 9, 1)..Date.new(2016, 8, 31))
      end
    end

    context "with previous month having all finalized meals" do
      before do
        create(:meal, :finalized, formula: formula, community: community, served_at: "2016-08-15 17:00")
        create(:meal, :finalized, formula: formula, community: community, served_at: "2016-09-15 17:00")
      end

      it "should end on month before previous month" do
        expect(report.send(:default_range)).to eq(Date.new(2015, 10, 1)..Date.new(2016, 9, 30))
      end
    end
  end

  describe "#empty?" do
    context "without finalized meals" do
      before do
        create(:meal, formula: formula, community: community)
      end

      it "should be empty" do
        expect(report).to be_empty
      end
    end

    context "with only finalized meals not in range" do
      before do
        meals = create_list(:meal, 2, :finalized, formula: formula, community: community,
                                                  served_at: 1.day.ago)
        meals.each do |m|
          m.signups << build(:meal_signup, meal: m, diner_counts: [2, 0, 0, 0])
          m.signups << build(:meal_signup, meal: m, diner_counts: [0, 1, 0, 0])
          m.save!
        end

        # The report range won't include these meals because one is unfinalized and they're on the same day.
        create(:meal, formula: formula, community: community, served_at: 1.day.ago)
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
        meals << create(:meal, :finalized, formula: formula, community: community, served_at: 1.month.ago)
        meals << create(:meal, :finalized, formula: formula, community: community, served_at: 6.months.ago)

        # Very old meal in different community.
        meals << create(:meal, :finalized, formula: formula, community: community2, served_at: 2.years.ago)

        # Meal in communityX. Should not show in results.
        meals << create(:meal, :finalized, formula: formula, community: communityX)

        meals.each do |m|
          m.signups << build(:meal_signup, meal: m, diner_counts: [2, 0, 0, 0])
          m.signups << build(:meal_signup, meal: m, diner_counts: [0, 1, 0, 0])
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
          create(:meal, formula: formula, community: community)
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
        meals << create(:meal, :finalized, formula: formula, community: community,
                                           served_at: "2016-01-01 18:00") # Fri
        meals << create(:meal, :finalized, formula: formula, community: community,
                                           served_at: "2016-02-10 18:00") # Wed
        meals << create(:meal, :finalized, formula: formula, community: community,
                                           served_at: "2016-02-12 18:00") # Fri
        meals << create(:meal, :finalized, formula: formula, community: community,
                                           served_at: "2016-04-05 18:00") # Tue
        hholds << create(:household, community: community)
        hholds << create(:household, community: community2)
        counts = [[5, 1], [7, 3], [4, 2], [8, 1]]
        meals.each_with_index do |m, i|
          # Assigns adult meals cost of $2.10, $4.20, $6.30, and $8.40, respectively.
          m.cost.parts[0].update!(value: 2.1 * (i + 1))

          # Assigns teen meals cost of 1.88. Serves as a decoy since we only check adult costs.
          m.cost.parts.create!(value: 1.88, type: m.formula.types[1])

          m.signups << build(:meal_signup, meal: m, diner_counts: [counts[i][0], 0, 0, 0],
                                           household: hholds[0])
          m.signups << build(:meal_signup, meal: m, diner_counts: [0, counts[i][1], 0, 0],
                                           household: hholds[1])
          m.save!
        end

        # Cancelled meal, should be ignored.
        m = create(:meal, :cancelled, formula: formula, community: community, served_at: "2016-04-12 18:00")
        m.signups << build(:meal_signup, meal: m, diner_counts: [2, 0, 0, 0], household: hholds[0])
        m.signups << build(:meal_signup, meal: m, diner_counts: [0, 2, 0, 0], household: hholds[1])
        m.save!

        # Cancelled meal in other community, should be ignored.
        m = create(:meal, :cancelled, formula: formula, community: community2, served_at: "2016-04-12 18:00")
        m.signups << build(:meal_signup, meal: m, diner_counts: [2, 0, 0, 0], household: hholds[0])
        m.signups << build(:meal_signup, meal: m, diner_counts: [0, 2, 0, 0], household: hholds[1])
        m.save!

        # Very old meal, should be ignored.
        create(:meal, :finalized, formula: formula, community: community, served_at: 2.years.ago)

        # Meals from community 2 and X
        meals2 = create_list(:meal, 2, :finalized, formula: formula, community: community2,
                                                   served_at: 2.months.ago)
        meals2.each do |meal|
          meal.signups << build(:meal_signup, meal: meal, diner_counts: [2, 0, 0, 0])
          meal.save!
        end
        meal3 = create(:meal, :finalized, formula: formula, community: communityX, served_at: 2.months.ago)
        meal3.signups << build(:meal_signup, meal: meal3, diner_counts: [2, 0, 0, 0])
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
          expect(jan["ttl_cost"]).to be_within(0.01).of(12)
          expect(jan["avg_max_cost"]).to be_within(0.01).of(2.10)

          expect(feb["ttl_meals"]).to eq(2)
          expect(feb["ttl_diners"]).to eq(16)
          expect(feb["ttl_cost"]).to be_within(0.01).of(24)
          expect(feb["avg_max_cost"]).to be_within(0.01).of(5.25)
          expect(feb["avg_diners"]).to be_within(0.01).of(8.0)
          expect(feb["avg_from_#{community.id}"]).to be_within(0.01).of(5.5)
          expect(feb["avg_from_#{community.id}_pct"]).to be_within(0.1).of(68.75)
          expect(feb["avg_from_#{community2.id}"]).to be_within(0.01).of(2.5)
          expect(feb["avg_from_#{community2.id}_pct"]).to be_within(0.1).of(31.25)

          expect(mar).to be_nil

          expect(apr["ttl_meals"]).to eq(1)
          expect(apr["ttl_diners"]).to eq(9)
          expect(apr["ttl_cost"]).to be_within(0.01).of(12)
          expect(apr["avg_max_cost"]).to be_within(0.01).of(8.40)

          expect(all["ttl_meals"]).to eq(4)
          expect(all["ttl_diners"]).to eq(31)
          expect(all["ttl_cost"]).to be_within(0.01).of(48)
          expect(all["avg_max_cost"]).to be_within(0.01).of(5.25)
          expect(all["avg_diners"]).to eq(7.75)
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

      describe "by_type" do
        it "should have correct data" do
          expect(report.by_type.size).to eq(4)
          expect(report.by_type.keys).to eq(["Adult", "Teen", "Kid", "Little Kid"])
          expect(report.by_type["Adult"]["avg_diners"]).to be_within(0.01).of(24.0 / 4.0)
          expect(report.by_type["Adult"]["avg_diners_pct"]).to be_within(0.01).of(100 * (24.0 / 4.0) / 7.75)
          expect(report.by_type["Teen"]["avg_diners"]).to be_within(0.01).of(7.0 / 4.0)
          expect(report.by_type["Teen"]["avg_diners_pct"]).to be_within(0.01).of(100 * (7.0 / 4.0) / 7.75)
          expect(report.by_type["Kid"]["avg_diners"]).to be_within(0.01).of(0)
          expect(report.by_type["Kid"]["avg_diners_pct"]).to be_within(0.01).of(0)
          expect(report.by_type["Little Kid"]["avg_diners"]).to be_within(0.01).of(0)
          expect(report.by_type["Little Kid"]["avg_diners_pct"]).to be_within(0.01).of(0)
        end
      end
    end
  end
end
