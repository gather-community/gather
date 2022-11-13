Gather.Views.Calendars.CalendarListView = Backbone.View.extend({
  initialize(options) {
    this.selection = options.selection || {};
    this.dontPersist = options.dontPersist || false;
    return this.loadSelection();
  },

  events: {
    "change input[type=checkbox]": "checkboxChanged"
  },

  checkboxChanged(e) {
    e.stopPropagation();
    this.$el.trigger("calendarSelectionChanged");
    return this.saveSelection();
  },

  selectedIds() {
    return this.$("input[type=checkbox]:checked").map((_, el) => el.value).get();
  },

  allSelected() {
    return this.$("input[type=checkbox]").get().every(el => this.$(el).is(":checked"));
  },

  saveSelection() {
    if (this.dontPersist) {
      return;
    }
    const entries = this.$("input[type=checkbox]").map((_, el) => [[el.value, this.$(el).prop("checked")]]);
    this.selection = Object.fromEntries(entries);
    Gather.loadingIndicator.show();
    $.ajax({
      url: "/users/update-setting",
      method: "PATCH",
      contentType: "application/json",
      data: JSON.stringify({settings: {calendar_selection: this.selection}}),
      success() {
        return Gather.loadingIndicator.hide();
      }
    });
  },

  loadSelection() {
    this.$("input[type=checkbox]:checked").each((_, el) => this.$(el).prop("checked", false));
    for (let id in this.selection) {
      let checked = this.selection[id];
      this.$(`input[type=checkbox][value=${id}]`).prop("checked", checked);
    }
  }
});
