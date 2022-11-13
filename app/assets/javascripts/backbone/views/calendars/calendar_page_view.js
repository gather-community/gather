Gather.Views.Calendars.CalendarPageView = Backbone.View.extend({
  initialize(options) {
    this.pageType = options.pageType;
    this.calendarView = options.calendarView;
    this.calendarId = options.calendarId;
    this.listView = options.listView;
    this.linkManager = options.linkManager;
    this.updateCalendarSource();
  },

  events: {
    'viewRender': 'onViewRender',
    'calendarSelectionChanged': 'updateCalendarSource'
  },

  onViewRender() {
    this.linkManager.update(this.calendarView.viewType(), this.calendarView.date());
  },

  updateCalendarSource() {
    let calendarIds = null;
    if (this.pageType === 'combined') { calendarIds = this.listView.selectedIds(); }
    if (this.pageType === 'single') { calendarIds = [this.calendarId]; }
    this.calendarView.updateSource(calendarIds);
  }
});
