Gather.Views.Work.JobReminderFieldsView = Backbone.View.extend({
  initialize() {
    // Force reevaluation of all slot counts
    this.$("select[id$=_abs_rel]").trigger("change");
  },

  events: {
    "change select[id$=_abs_rel]": "absRelChanged",
    "cocoon:after-insert": "reminderInserted"
  },

  absRelChanged(event) {
    this.toggleFields(this.$(event.target).closest(".nested-fields"));
  },

  reminderInserted(event, inserted) {
    const row = this.$(inserted);
    row.trigger('page:change'); // Force recognition of datepicker in pickers.js
    this.toggleFields(row);
  },

  toggleFields(row) {
    const isAbsTime = row.find("select[id$=_abs_rel]").val() === "absolute";
    row.find(".work_job_reminders_abs_time").toggle(isAbsTime);
    row.find(".work_job_reminders_rel_magnitude").toggle(!isAbsTime);
    row.find(".work_job_reminders_rel_unit_sign").toggle(!isAbsTime);
  }
});
