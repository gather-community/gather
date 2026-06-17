Gather.Views.Calendars.CalendarPageView = Backbone.View.extend({
  initialize(options) {
    this.pageType = options.pageType;
    this.calendarView = options.calendarView;
    this.calendarId = options.calendarId;
    this.listView = options.listView;
    this.linkManager = options.linkManager;
    this._lastViewType = null;
    this._lastDate = null;
    this._dateCommitted = false;
    const url = new URL(window.location.href);
    this._viewParamOnLoad = url.searchParams.get("view");
    this._dateParamOnLoad = url.searchParams.get("date");
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
    const viewType = this.calendarView.viewType();
    const date = this.calendarView.date();
    const earlyMorning = this.calendarView.viewParams.earlyMorning;

    // Include view in URL/links only when the user explicitly picks a view, not on
    // next/prev. On the first render, honour a view param that was already in the URL.
    // Include date only after the user navigates (date changes while view stays the same),
    // or when the page loaded with a date param. Once committed, both persist.
    let includeView, includeDate;
    if (this._lastViewType === null) {
      includeView = !!this._viewParamOnLoad;
      includeDate = !!this._dateParamOnLoad;
    } else {
      includeView = viewType !== this._lastViewType;
      const navigated = viewType === this._lastViewType && date !== this._lastDate;
      includeDate = navigated || this._dateCommitted;
    }
    if (includeDate) this._dateCommitted = true;
    this._lastViewType = viewType;
    this._lastDate = date;

    this.linkManager.update(viewType, date, {skipUrl: this._restoringHistory, includeView, includeDate, earlyMorning});
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
