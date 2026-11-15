# frozen_string_literal: true

require "rails_helper"

describe Gather::LocalizedDate do
  def normalize(value, locale)
    I18n.with_locale(locale) { described_class.normalize(value) }
  end

  # The first day of each month, so every month name and most weekday names come up.
  let(:dates) { (1..12).map { |month| Date.new(2026, month, month + 10) } }

  (I18n.available_locales - [:en]).each do |locale|
    it "reads back every format a #{locale} picker shows" do
      I18n.with_locale(locale) do
        date_format = I18n.t("datepicker.dformat")
        time_format = I18n.t("timepicker.dformat")
        dates.each do |date|
          time = Time.zone.local(date.year, date.month, date.day, date.month + 7, 5)
          iso_date = date.iso8601
          iso_time = time.strftime("%H:%M")

          expect(described_class.normalize(I18n.l(date, format: date_format))).to eq(iso_date)
          expect(described_class.normalize(I18n.l(date, format: "%a #{date_format}"))).to eq(iso_date)
          expect(described_class.normalize(I18n.l(time, format: "#{date_format} #{time_format}")))
            .to eq("#{iso_date} #{iso_time}")
          expect(described_class.normalize(I18n.l(time, format: "%a #{date_format} #{time_format}")))
            .to eq("#{iso_date} #{iso_time}")
          expect(described_class.normalize(I18n.l(time, format: time_format))).to eq(iso_time)
        end
      end
    end
  end

  it "tells French Tuesday from March by position" do
    expect(normalize("mar 3 mars 2026", :fr)).to eq("2026-03-03")
    expect(normalize("mar 31 mars 2026 18:30", :fr)).to eq("2026-03-31 18:30")
  end

  it "ignores case and extra spaces, as when typed" do
    expect(normalize(" 5.  OKT 2026 ", :de)).to eq("2026-10-05")
    expect(normalize("5 oct. 2026 18 h 30", :"fr-CA")).to eq("2026-10-05 18:30")
  end

  it "takes other formats, and gives a date with no year as --MM-DD" do
    formats = ["%-d. %b %Y", "%-d. %b"]
    I18n.with_locale(:de) do
      expect(described_class.normalize("5. Okt 1990", formats: formats)).to eq("1990-10-05")
      expect(described_class.normalize("5. Okt", formats: formats)).to eq("--10-05")
    end
  end

  it "leaves English to Ruby's parser" do
    expect(normalize("Oct 05 2026  6:30pm", :en)).to eq("Oct 05 2026  6:30pm")
  end

  it "leaves values that don't match a picker format unchanged" do
    expect(normalize("2026-10-05", :de)).to eq("2026-10-05")
    expect(normalize("2026-10-05T18:30:00Z", :de)).to eq("2026-10-05T18:30:00Z")
    expect(normalize("next Tuesday", :de)).to eq("next Tuesday")
    expect(normalize("", :de)).to eq("")
    expect(normalize(nil, :de)).to be_nil
    date = Date.new(2026, 10, 5)
    expect(normalize(date, :de)).to eq(date)
  end

  describe "casting" do
    around { |example| I18n.with_locale(:de) { example.run } }

    it "applies to date, datetime and time columns" do
      expect(Work::Period.new(starts_on: "5. Okt 2026").starts_on).to eq(Date.new(2026, 10, 5))
      expect(build(:meal, served_at: "Mo 5. Okt 2026 18:30").served_at)
        .to eq(Time.zone.local(2026, 10, 5, 18, 30))
      expect(build(:calendar_protocol, fixed_start_time: "18:30").fixed_start_time.strftime("%H:%M"))
        .to eq("18:30")
    end

    it "applies to Finnish times, which Ruby can't read" do
      I18n.with_locale(:fi) do
        expect(build(:calendar_protocol, fixed_start_time: "8.05").fixed_start_time.strftime("%H:%M"))
          .to eq("08:05")
        expect(build(:meal,
          served_at: "5.10.2026 18.30").served_at).to eq(Time.zone.local(2026, 10, 5, 18, 30))
      end
    end

    it "fixes values Ruby's parser gets wrong without an error" do
      expect(Time.zone.parse("5.10.2026 18.30").hour).to eq(0)
      expect(Time.zone.parse("5 oct. 2026 18 h 30").min).to eq(0)
      I18n.with_locale(:fi) do
        expect(build(:meal, served_at: "5.10.2026 18.30").served_at.hour).to eq(18)
      end
      I18n.with_locale(:"fr-CA") do
        expect(build(:meal, served_at: "5 oct. 2026 18 h 30").served_at.min).to eq(30)
      end
    end
  end
end
