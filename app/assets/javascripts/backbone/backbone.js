/* eslint-disable */
//= require_self

// Must be loaded early due to inheritance
//= require ./views/print_view

//= require_tree ./views
/* eslint-enable */

window.Gather = {
  // Machine-readable formats. Formats people see are under moment_formats in the locale files.
  TIME_FORMATS: {
    machineDatetime: "YYYY-MM-DD HH:mm",
    compactDate: "YYYY-MM-DD"
  },
  Models: {},
  Collections: {},
  Routers: {},
  Views: {
    Meals: {},
    People: {},
    Work: {},
    Calendars: {},
    Groups: {},
    Billing: {},
    GDrive: {}
  }
};
