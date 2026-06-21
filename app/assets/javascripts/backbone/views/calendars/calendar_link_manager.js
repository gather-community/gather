Gather.Views.Calendars.CalendarLinkManager = Backbone.View.extend({
  initialize(options) {
    this.calendarId = options.calendarId;
    this._committedViewType = null;
    this._dateCommitted = false;
  },

  // includeView: user explicitly picked a view (or one was in the URL on load).
  // includeDate: user navigated to a different date (or date was in the URL on load).
  // Both are sticky once committed. earlyMorning is always reflected immediately.
  update(viewType, date, {skipUrl = false, includeView = false, includeDate = false, earlyMorning = false} = {}) {
    if (includeView) this._committedViewType = viewType;
    if (includeDate) this._dateCommitted = true;
    // null means "delete this param from the URL/link" (absent when off/uncommitted).
    const early = earlyMorning || null;
    this.updatePermalink({view: viewType, date, early});
    const navParams = {early};
    if (this._committedViewType !== null) navParams.view = this._committedViewType;
    if (this._dateCommitted) navParams.date = date;
    this.updateCalendarLinks(navParams);
    if (!skipUrl) this.updateBrowserUrl(navParams);
  },

  updatePermalink(qsParams) {
    return this.updateLink(this.$("#permalink"), qsParams);
  },

  // Update all calendar sidebar links so navigating to another calendar preserves
  // the current view and date. Only applies on single-calendar pages — the combined
  // events page has no specific context to carry and should let each calendar's
  // default view take effect.
  updateCalendarLinks(qsParams) {
    if (!this.calendarId) return;
    $(".calendar-link").each((_, el) => this.updateLink($(el), qsParams));
  },

  // Skip URL update on the initial render so the URL stays clean on page load,
  // matching lens behaviour (params only appear after the user navigates).
  // Subsequent navigations push a history entry so the URL stays in sync.
  updateBrowserUrl(qsParams) {
    if (!this._initialized) {
      this._initialized = true;
      return;
    }
    const url = new URL(window.location.href);
    this._applyParams(url, qsParams);
    history.pushState(null, "", url.pathname + url.search);
  },

  updateLink(link, qsParams) {
    const $link = $(link);
    const path = $link.attr("href");
    if (!path) return;
    const url = new URL(path, "https://example.com");
    this._applyParams(url, qsParams);
    $link.attr("href", url.href.replace("https://example.com", ""));
  },

  // Set params that have a value; delete params whose value is null (absent/off).
  _applyParams(url, qsParams) {
    Object.keys(qsParams).forEach(k => {
      if (qsParams[k] == null) {
        url.searchParams.delete(k);
      } else {
        url.searchParams.set(k, qsParams[k]);
      }
    });
  }
});
