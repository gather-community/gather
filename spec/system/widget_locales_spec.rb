# frozen_string_literal: true

require "rails_helper"

# The JS widgets in each locale (see app/assets/javascripts/locale_setup.js). Pages can't be shown in other
# locales in specs until they're translated, so this calls the setup for each locale on an English page.
describe "widget locales", js: true do
  let(:user) { create(:user) }

  before do
    use_user_subdomain(user)
    login_as(user, scope: :user)
  end

  # A date in each month, so every month name and weekday comes up, with a time to go with it.
  let(:times) { (1..12).map { |month| Time.zone.local(2026, month, month + 10, month + 7, 5) } }

  # What Rails writes into each kind of picker, the moment.js format the picker reads it with, and the
  # moment.js format to show what it read.
  def picker_kinds
    date = [I18n.t("datepicker.dformat"), I18n.t("datepicker.pformat")]
    time = [I18n.t("timepicker.dformat"), I18n.t("timepicker.pformat")]
    {
      date: [*date, "YYYY-MM-DD"],
      wday_date: ["%a #{date[0]}", "ddd #{date[1]}", "YYYY-MM-DD"],
      date_time: ["#{date[0]} #{time[0]}", "#{date[1]} #{time[1]}", "YYYY-MM-DD HH:mm"],
      time: [*time, "HH:mm"]
    }
  end

  def picker_cases(locale)
    I18n.with_locale(locale) do
      picker_kinds.values.product(times).map do |(dformat, pformat, check_format), time|
        {text: ApplicationController.helpers.l(time, format: dformat), format: pformat,
         check_format: check_format, expected: time.strftime(moment_to_strftime(check_format))}
      end
    end
  end

  def moment_to_strftime(format)
    format.sub("YYYY", "%Y").sub("MM", "%m").sub("DD", "%d").sub("HH", "%H").sub("mm", "%M")
  end

  # Sets up the locale in the page, then has moment.js read each case and write it back out.
  def read_back(locale, cases)
    page.evaluate_script(<<~JS)
      (function(lang, cases) {
        WidgetLocales.setUp(lang);
        return cases.map(function(c) {
          var parsed = moment(c.text, c.format);
          return {read: parsed.format(c.check_format), written: parsed.format(c.format)};
        });
      })(#{locale.to_s.to_json}, #{cases.to_json})
    JS
  end

  scenario "date pickers read back what Rails writes, in every locale" do
    visit(meals_path)
    I18n.available_locales.each do |locale|
      cases = picker_cases(locale)
      results = read_back(locale, cases)
      cases.zip(results).each do |c, result|
        expect(result["read"]).to eq(c[:expected]), "#{locale} read #{c[:text].inspect} as #{result["read"]}"
        expect(result["written"]).to eq(c[:text]), "#{locale} wrote #{result["written"].inspect}"
      end
    end
  end

  scenario "each widget uses the locale and its week start" do
    visit(meals_path)
    I18n.available_locales.each do |locale|
      settings = page.evaluate_script(<<~JS)
        (function(lang) {
          WidgetLocales.setUp(lang);
          return {
            moment: moment.locale(),
            weekStart: moment.localeData().firstDayOfWeek(),
            fullCalendar: $.fullCalendar.Calendar.defaults.locale,
            select2: $.fn.select2.defaults.defaults.language
          };
        })(#{locale.to_s.to_json})
      JS
      code = locale.to_s.downcase
      sunday_start = %w[en fr-ca].include?(code)
      expect(settings).to eq("moment" => code, "weekStart" => sunday_start ? 0 : 1,
        "fullCalendar" => code, "select2" => code)
    end
  end
end
