Gather.Views.Meals.RoleFormView = Backbone.View.extend({

  initialize(options) {
    this.$("#meals_role_time_type").trigger("change");
  },

  events: {
    "change #meals_role_time_type": "toggleOffsetsAndHours"
  },

  toggleOffsetsAndHours() {
    this.$(".form-group.meals_role_shift_start").toggle(this.isDateTime());
    this.$(".form-group.meals_role_shift_end").toggle(this.isDateTime());
    this.$(".form-group.meals_role_work_hours").toggle(!this.isDateTime());
  },

  isDateTime() {
    return this.timeType() === "date_time";
  },

  timeType() {
    return this.$("#meals_role_time_type").val();
  }
});
