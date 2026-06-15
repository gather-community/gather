/* eslint-disable */
//= require_self

// Must be loaded early due to inheritance
//= require ./views/print_view

//= require_tree ./views
/* eslint-enable */

window.Gather = {
  TIME_FORMATS: {
    fullDatetime: "ddd MMM D YYYY h:mm a",
    machineDatetime: "YYYY-MM-DD HH:mm",
    regDate: "ddd MMM DD YYYY",
    regTime: "h:mm a",
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
