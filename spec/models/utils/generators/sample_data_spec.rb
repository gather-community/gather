# frozen_string_literal: true

require "rails_helper"

# Communities are generated in their own language, so every language's starter content and sample data must
# fit the columns they go in. A name that's too long, or two calendars with the same name, would make
# community setup fail. Generating a community in every language would catch this too, but slowly.
describe "Sample data translations" do
  # The column limits on calendar_nodes.
  calendar_name_max_length = 24
  calendar_abbrv_max_length = 6

  Gather::Locales::TRANSLATED.each do |locale|
    context "in #{locale}" do
      around { |example| I18n.with_locale(locale, &example) }

      it "has calendar names that fit and differ from each other" do
        names = %w[calendars calendar_groups].flat_map do |section|
          keys(:en, "starter_content.#{section}").map { |k| I18n.t("starter_content.#{section}.#{k}") }
        end
        names += %w[all_meals my_meals my_jobs].map { |k| I18n.t("calendars.#{k}") }
        names += keys(:en, "sample_data.calendars").map { |k| I18n.t("sample_data.calendars.#{k}.name") }
        expect(names.select { |n| n.size > calendar_name_max_length }).to be_empty
        expect(names.tally.select { |_, count| count > 1 }.keys).to be_empty
      end

      it "has calendar abbreviations that fit" do
        abbrvs = keys(:en, "sample_data.calendars").filter_map do |k|
          I18n.t("sample_data.calendars.#{k}.abbrv") if I18n.exists?("sample_data.calendars.#{k}.abbrv")
        end
        expect(abbrvs.select { |a| a.size > calendar_abbrv_max_length }).to be_empty
      end

      it "has event, group and guideline names that fit" do
        max = Calendars::EventForm::NAME_MAX_LENGTH
        expect(I18n.t("sample_data.event_names").select { |n| n.size > max }).to be_empty
        expect(I18n.t("sample_data.weekly_event").size).to be <= max
        %i[meals_committee knitting_club].each do |key|
          expect(I18n.t("sample_data.groups.#{key}.name").size).to be <= Groups::Group::NAME_MAX_LENGTH
        end
        expect(I18n.t("sample_data.shared_guidelines.common_house.name").size).to be <= 64
      end

      # The meal form offers the community's allergens plus any a meal already has, so a sample meal's
      # "Soy" must be written the same way as the community's, or it would be listed twice.
      it "names allergens the way the community's allergen list does" do
        list = I18n.t("starter_content.allergens").split(/\s*,\s*/)
        expect(list).to include(I18n.t("sample_data.allergens.dairy"), I18n.t("sample_data.allergens.soy"))
      end

      it "has a distinct title for each sample work job" do
        titles = keys(:en, "sample_data.work.jobs").map { |k| I18n.t("sample_data.work.jobs.#{k}") }
        titles << I18n.t("starter_content.meal_roles.head_cook.title")
        expect(titles.uniq.size).to eq(titles.size)
      end
    end
  end

  # The keys under `scope`, from English since fr-CA has only some of them (the rest fall back to fr).
  def keys(locale, scope)
    I18n.t(scope, locale: locale).keys
  end

  # The data files name their text by key. A key with no text would make generation fail.
  it "has text for every key the sample data files use" do
    dir = Rails.root.join("lib/random_data/data")
    load = ->(path) { YAML.safe_load_file(dir.join(path), permitted_classes: [Symbol, Time, Date]) }
    load.call("calendars/calendars.yml").each do |row|
      expect(I18n.exists?("sample_data.calendars.#{row["key"]}.name", :en)).to be(true), row["key"]
    end
    load.call("calendars/shared_guidelines.yml").each do |row|
      expect(I18n.exists?("sample_data.shared_guidelines.#{row["key"]}.body", :en)).to be(true), row["key"]
    end
    meals = load.call("meals/meals.yml")
    meals.each do |row|
      expect(I18n.exists?("sample_data.meals.#{row["key"]}.title", :en)).to be(true), row["key"]
      row["allergens"].each do |allergen|
        expect(I18n.exists?("sample_data.allergens.#{allergen}", :en)).to be(true), allergen
      end
    end
    # MealGenerator makes one meal per entry, two a week for 5 months.
    expect(meals.size).to eq(Utils::Generators::MealGenerator::MONTHS * 4 * 2)
    load.call("calendars/events.yml").map { |row| row["kind"] }.uniq.each do |kind|
      expect(I18n.exists?("sample_data.event_kinds.#{kind}", :en)).to be(true), kind
    end
  end
end
