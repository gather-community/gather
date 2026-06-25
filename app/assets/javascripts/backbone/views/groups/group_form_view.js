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
    return this.$(".groups_group_availability select").val() === "everybody";
  },

  handleListNameChanged() {
    const val = this.$("#groups_group_mailman_list_attributes_name").val();
    this.$(".list-form-details").toggle(val !== "");
  },

  handleSubmit(event) {
    const deletingList = this.$("#groups_group_mailman_list_attributes__destroy").is(":checked");

    // Allow the submit if there's no list to delete, or if we've already confirmed and re-fired.
    if (!deletingList || this.listDeletionConfirmed) {
      this.listDeletionConfirmed = false;
      return true;
    }

    // The modal is async, so block this submit and re-fire it once confirmed.
    event.preventDefault();
    this.$el.data("submitted", false);
    window.Modal.confirmModal("Are you sure you want to delete the email list?").then(ok => {
      if (!ok) {
        return;
      }
      this.listDeletionConfirmed = true;
      this.$el.submit();
    });
    return false;
  }
});
