Gather.Views.Calendars.CalendarListView = Backbone.View.extend({
  initialize(options) {
    this.selection = options.selection || {};
    this.dontPersist = options.dontPersist || false;
    this.communityId = options.communityId;
    this.loadSelection();
  },

  events: {
    "change input[type=checkbox]": "checkboxChanged",
    "click .select-all-link": "selectAllClicked"
  },

  checkboxChanged(e) {
    e.stopPropagation();
    this.$el.trigger("calendarSelectionChanged");
    this.saveSelection();
    this.updateSelectAllLink();
  },

  selectAllClicked(e) {
    e.preventDefault();
    const checked = !this.allSelected();
    this.$("input[type=checkbox]").prop("checked", checked);
    this.$el.trigger("calendarSelectionChanged");
    this.saveSelection();
    this.updateSelectAllLink();
  },

  updateSelectAllLink() {
    this.$(".select-all-link").text(this.allSelected() ? "Deselect All" : "Select All");
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
    const settingsKey = `calendar_selection_${this.communityId}`;
    Gather.loadingIndicator.show();
    $.ajax({
      url: "/users/update-setting",
      method: "PATCH",
      contentType: "application/json",
      data: JSON.stringify({settings: {[settingsKey]: this.selection}}),
      success() {
        Gather.loadingIndicator.hide();
      }
    });
  },

  loadSelection() {
    this.$("input[type=checkbox]:checked").each((_, el) => this.$(el).prop("checked", false));
    for (let id in this.selection) {
      let checked = this.selection[id];
      this.$(`input[type=checkbox][value=${id}]`).prop("checked", checked);
    }
    this.updateSelectAllLink();
  }
});
