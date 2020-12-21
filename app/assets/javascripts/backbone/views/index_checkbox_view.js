// Handles checkboxes for selecting rows on an index table.
Gather.Views.IndexCheckboxView = class IndexCheckboxView extends Backbone.View {
  get events() {
    return {
      "click th.index-checkbox input[type=checkbox]": "handleSelectAll",
      "click td.index-checkbox input[type=checkbox]": "handleSelect",
    };
  }

  handleSelectAll(e) {
    const checked = e.currentTarget.checked;
    this.tdBoxes().prop("checked", checked);
  }

  handleSelect() {
    const allChecked = this.tdBoxes(true).length === this.tdBoxes().length;
    this.$("th.index-checkbox input[type=checkbox]").prop("checked", allChecked);
  }

  tdBoxes(checked) {
    const suffix = checked ? ":checked" : "";
    return this.$(`td input[type=checkbox]${suffix}`);
  }
};
