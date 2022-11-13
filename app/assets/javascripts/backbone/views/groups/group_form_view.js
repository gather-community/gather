Gather.Views.Groups.GroupFormView = Backbone.View.extend({

  initialize(options) {
    this.handleAvailabilityChanged();
    this.handleListNameChanged();
  },

  events: {
    "change #groups_group_availability": "handleAvailabilityChanged",
    "cocoon:after-insert .groups_group_memberships": "handleMembershipRowInserted",
    "keyup #groups_group_mailman_list_attributes_name": "handleListNameChanged",
    "submit": "handleSubmit"
  },

  handleAvailabilityChanged() {
    const everybody = this.everybody();
    this.$(".groups_group_memberships .nested-fields").each(function() {
      const kind = $(this).find(".groups_group_memberships_kind select").val();
      $(this).toggle((everybody && (kind !== "joiner")) || (!everybody && (kind !== "opt_out")));
    });
  },

  handleMembershipRowInserted(event, row) {
    if (this.everybody()) {
      row.find("option[value=joiner]").remove();
    } else {
      row.find("option[value=opt_out]").remove();
    }
  },

  everybody() {
    this.$(".groups_group_availability select").val() === "everybody";
  },

  handleListNameChanged() {
    const val = this.$("#groups_group_mailman_list_attributes_name").val();
    this.$(".list-form-details").toggle(val !== "");
  },

  handleSubmit(event) {
    if (this.$("#groups_group_mailman_list_attributes__destroy").is(":checked")) {
      if (confirm("Are you sure you want to delete the email list?")) {
        return true;
      } else {
        this.$el.data("submitted", false);
        return false;
      }
    } else {
      return true;
    }
  }
});
