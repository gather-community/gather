Gather.Views.Calendars.ExportView = Backbone.View.extend({
  initialize(options) {
    this.listView = options.listView;
    this.communityToken = options.communityToken;
    this.userToken = options.userToken;
    this.rootUrl = options.rootUrl;
    this.rebuildUrl();
  },

  events: {
    "click .calendar-list-wrapper input": "rebuildUrl",
    "click #calendars_export_dont_personalize": "rebuildUrl",
    "click #calendars_export_own_only": "rebuildUrl",
    "click #copy-link": "copyLink",
    "click #visit-link": "visitLink"
  },

  rebuildUrl() {
    const base = this.rootUrl.replace(/https?:/, "webcal:");
    let params = [];
    params.push(`calendars=${this.calendarIds()}`);
    params.push(`token=${this.token()}`);
    if (this.personalized() && this.ownOnly()) {
      params.push("own_only=1");
    }
    this.$("#export-url").val(`${base}${this.path()}?${params.join("&")}`);
    this.toggleOwnOnlyCheckbox();
  },

  calendarIds() {
    return this.listView.allSelected() ? "all" : this.listView.selectedIds().join("+");
  },

  path() {
    return this.personalized() ? "calendars/export.ics" : "calendars/community-export.ics";
  },

  token() {
    return this.personalized() ? this.userToken : this.communityToken;
  },

  personalized() {
    return !this.$("#calendars_export_dont_personalize").is(":checked");
  },

  ownOnly() {
    return this.$("#calendars_export_own_only").is(":checked");
  },

  url() {
    return this.$("#export-url").val();
  },

  copyLink(event) {
    copyTextToClipboard(this.url());
    event.preventDefault();
  },

  visitLink(event) {
    window.location.href = this.url();
    event.preventDefault();
  },

  toggleOwnOnlyCheckbox() {
    this.$(".form-group.calendars_export_own_only").toggle(this.personalized());
  }
});
