Gather.Views.People.MemorialFormView = Backbone.View.extend({
  initialize(options) {
    this.birthYears = options.birthYears;
  },

  events: {
    "change #people_memorial_user_id": "userChanged"
  },

  userChanged(event) {
    const userId = parseInt(this.$(event.target).val());
    const year = this.birthYears[userId];
    if (year) {
      this.$("#people_memorial_birth_year").val(year);
    }
  }
});
