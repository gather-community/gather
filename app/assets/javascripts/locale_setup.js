// Puts the widgets in this bundle (moment.js and the date pickers, FullCalendar and Select2) in the page's
// locale, which comes from <html lang>. Their locale packs come from locale_packs.js. Loading a pack makes
// it the global default, so the last pack loaded would win if this didn't reset them all.
//
// legacy.js requires this before pickers.js so it's the first thing to run on document ready. It waits for
// ready because it needs the Rails translations, which the deferred application bundle provides as
// window.I18n. Exposed as window.WidgetLocales so specs can set up other locales.
(function() {
  // Parsing rules a locale pack builds for moment's own month and weekday names.
  var NAME_PARSING_KEYS = [
    "monthsRegex", "monthsShortRegex", "monthsStrictRegex", "monthsShortStrictRegex", "monthsParse",
    "longMonthsParse", "shortMonthsParse", "weekdaysRegex", "weekdaysShortRegex", "weekdaysMinRegex",
    "weekdaysStrictRegex", "weekdaysShortStrictRegex", "weekdaysMinStrictRegex", "weekdaysParse"
  ];

  // lang is a Rails locale, e.g. "fr-CA". The widgets use lowercase codes.
  function setUp(lang) {
    var locale = lang.toLowerCase();
    if (locale !== "en") {
      useRailsNames(locale, lang);
    }
    moment.locale(locale);
    $.fullCalendar.locale(locale);
    $.fn.select2.defaults.set("language", locale);
  }

  // A date picker's field is filled in by Rails and read back by moment.js, so their month and weekday
  // names have to match exactly. rails-i18n and moment.js don't always agree (German "Mär" and "März"),
  // so this gives moment.js the Rails names and has it parse exactly those.
  function useRailsNames(locale, lang) {
    var data = moment.localeData(locale);
    if (!data || data._abbr !== locale) {
      return;
    }
    var config = $.extend({}, data._config, {
      months: I18n.t("date.month_names", {locale: lang}).slice(1),
      monthsShort: I18n.t("date.abbr_month_names", {locale: lang}).slice(1),
      monthsParseExact: true,
      weekdays: I18n.t("date.day_names", {locale: lang}),
      weekdaysShort: I18n.t("date.abbr_day_names", {locale: lang}),
      weekdaysParseExact: true
    });
    NAME_PARSING_KEYS.forEach(function(key) { delete config[key]; });
    moment.defineLocale(locale, null);
    moment.defineLocale(locale, config);
  }

  window.WidgetLocales = {setUp: setUp};

  $(function() {
    setUp(document.documentElement.lang || "en");
  });
})();
