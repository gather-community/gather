Gather.Views.Calendars.CalendarPageView = Backbone.View.extend({
  initialize(options) {
    this.pageType = options.pageType;
    this.calendarView = options.calendarView;
    this.calendarId = options.calendarId;
    this.listView = options.listView;
    this.linkManager = options.linkManager;
    window.addEventListener("popstate", this.onPopState.bind(this));
    this.updateCalendarSource();
  },

  events: {
    "viewRender": "onViewRender",
    "calendarSelectionChanged": "updateCalendarSource"
  },

  onPopState() {
    const url = new URL(window.location.href);
    this._restoringHistory = true;
    this.calendarView.navigateTo(url.searchParams.get("view"), url.searchParams.get("date"));
  },

  onViewRender() {
    this.linkManager.update(this.calendarView.viewType(), this.calendarView.date(),
      {skipUrl: this._restoringHistory});
    this._restoringHistory = false;
  },

  updateCalendarSource() {
    let calendarIds = null;
    if (this.pageType === "combined") {
      calendarIds = this.listView.selectedIds();
    }
    if (this.pageType === "single") {
      calendarIds = [this.calendarId];
    }
    this.calendarView.updateSource(calendarIds);
  }
});
