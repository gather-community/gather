Gather.Views.Calendars.CalendarLinkManager = Backbone.View.extend({
  update(viewType, date) {
    const qsParams = {view: viewType, date};
    this.updatePermalink(qsParams);
    this.updateBrowserUrl(qsParams);
  },

  updatePermalink(qsParams) {
    return this.updateLink(this.$("#permalink"), qsParams);
  },

  // Use replaceState on first render (preserves initial history entry), pushState on
  // subsequent navigations so the browser back button steps through calendar dates.
  updateBrowserUrl(qsParams) {
    const url = new URL(window.location.href);
    Object.keys(qsParams).forEach(k => url.searchParams.set(k, qsParams[k]));
    const method = this._initialized ? "pushState" : "replaceState";
    history[method](null, "", url.pathname + url.search);
    this._initialized = true;
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
