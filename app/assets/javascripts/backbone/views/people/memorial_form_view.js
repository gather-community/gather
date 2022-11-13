Gather.Views.People.MemorialFormView = Backbone.View.extend({

  initialize(options) {
    this.birthYears = options.birthYears;
  },

  events: {
    'change #people_memorial_user_id': 'userChanged'
  },

  userChanged(event) {
    let year;
    const userId = parseInt(this.$(event.target).val());
    if (year = this.birthYears[userId]) {
      this.$('#people_memorial_birth_year').val(year);
    }
  }
});
