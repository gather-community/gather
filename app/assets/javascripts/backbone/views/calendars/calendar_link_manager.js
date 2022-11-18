Gather.Views.Calendars.CalendarLinkManager = Backbone.View.extend({
  update(viewType, date) {
    const qsParams = {view: viewType, date};
    return this.updatePermalink(qsParams);
  },

  updatePermalink(qsParams) {
    return this.updateLink(this.$("#permalink"), qsParams);
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
