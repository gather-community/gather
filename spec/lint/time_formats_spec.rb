# frozen_string_literal: true

require "rails_helper"

# Date and time formats are written by hand for each locale (config/locales/*/time_formats.yml), so nothing
# else checks they're complete. Gather::LocalizedDate and the widget locale system spec check the picker
# formats read back.
describe "time formats" do
  def keys(hash, prefix = nil)
    hash.flat_map do |key, value|
      path = [prefix, key].compact.join(".")
      value.is_a?(Hash) ? keys(value, path) : [path]
    end
  end

  def formats(locale)
    YAML.load_file(Rails.root.join("config/locales/#{locale}/time_formats.yml"))[locale.to_s]
  end

  let(:en_keys) { keys(formats(:en)) }
  let(:time) { Time.zone.local(2026, 10, 5, 18, 30) }

  (I18n.available_locales - [:en]).each do |locale|
    describe locale do
      it "has every format English has, and no others" do
        expect(keys(formats(locale))).to match_array(en_keys)
      end

      it "uses 24-hour time" do
        strftime = formats(locale).values_at("date", "time").flat_map { |group| group["formats"].values }
        strftime += formats(locale).values_at("datepicker", "timepicker").pluck("dformat")
        expect(strftime.grep(/%-?[lIpP]/)).to be_empty
      end

      it "renders every date and time format" do
        I18n.with_locale(locale) do
          formats(locale)["date"]["formats"].each_key do |name|
            expect(I18n.l(time.to_date, format: name.to_sym)).to be_present
          end
          formats(locale)["time"]["formats"].each_key do |name|
            minutes = name.end_with?("no_time") ? nil : time.strftime("%M")
            expect(I18n.l(time, format: name.to_sym)).to include(minutes.to_s)
          end
        end
      end
    end
  end
end
