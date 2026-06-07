Gather.Views.Calendars.CalendarLinkManager = Backbone.View.extend({
  update(viewType, date) {
    const qsParams = {view: viewType, date};
    this.updatePermalink(qsParams);
    this.updateBrowserUrl(qsParams);
  },

  updatePermalink(qsParams) {
    return this.updateLink(this.$("#permalink"), qsParams);
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
    Object.keys(qsParams).forEach(k => url.searchParams.set(k, qsParams[k]));
    history.pushState(null, "", url.pathname + url.search);
  },

  updateLink(link, qsParams) {
    let href;
    let path = (href = this.$(link).attr("href"));
    const url = new URL(path, "https://example.com");
    Object.keys(qsParams).forEach(k => url.searchParams.set(k, qsParams[k]));
    path = url.href.replace("https://example.com", "");
    return $(link).attr("href", path);
  }
});
