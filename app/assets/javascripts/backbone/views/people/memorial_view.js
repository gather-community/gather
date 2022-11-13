Gather.Views.People.MemorialView = Backbone.View.extend({
  initialize(options) {
    this.draftMessageChanged();
  },

  events: {
    'keyup #people_memorial_message_body': 'draftMessageChanged'
  },

  draftMessageChanged() {
    const blank = this.$('#people_memorial_message_body').val().trim() === '';
    this.$('.people--memorial-message-form .btn-primary').toggle(!blank);
  }
});
