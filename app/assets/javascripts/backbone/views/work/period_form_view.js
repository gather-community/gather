Gather.Views.Work.PeriodFormView = Backbone.View.extend({
  initialize() {
    this.quotaTypeOrPhaseChanged();
    this.pickTypeChanged();
    this.jobCopySourceIdChanged();
    this.mealJobSyncChanged();
  },

  events: {
    "change #work_period_quota_type": "quotaTypeOrPhaseChanged",
    "change #work_period_phase": "quotaTypeOrPhaseChanged",
    "change #work_period_pick_type": "pickTypeChanged",
    "change #work_period_job_copy_source_id": "jobCopySourceIdChanged",
    "change #work_period_meal_job_sync": "mealJobSyncChanged",
    "click .priority-icon": "priorityChanged"
  },

  quotaTypeOrPhaseChanged() {
    const notNone = this.$("#work_period_quota_type").val() !== "none";
    this.$(".work_period_pick_type").toggle(notNone);
    const showShares = notNone && (this.$("#work_period_phase").val() !== "archived");
    this.$(".shares").toggle(showShares);
    this.$el.toggleClass("full-width", showShares);
    this.$el.toggleClass("normal-width", !showShares);
  },

  pickTypeChanged() {
    const staggered = this.$("#work_period_pick_type").val() === "staggered";
    this.$(".staggering-options").toggle(staggered);
    this.$(".priority-icon").toggle(staggered);
    this.$(".priority-hint").toggle(staggered);
  },

  priorityChanged(e) {
    const icon = this.$(e.currentTarget);
    const newVal = icon.html() === "☆";
    icon.closest(".work-share").find("input[id$=_priority]").val(newVal ? "true" : "false");
    const newGlyph = newVal ? "★" : "☆";
    icon.html(newGlyph);
  },

  jobCopySourceIdChanged() {
    const copying = this.$("#work_period_job_copy_source_id").val() !== '';
    this.$(".work_period_copy_preassignments").toggle(copying);
  },

  mealJobSyncChanged() {
    const sync = this.$("#work_period_meal_job_sync").val() === 'true';
    this.$("#meal-job-sync-settings").toggle(sync);
  }
});
