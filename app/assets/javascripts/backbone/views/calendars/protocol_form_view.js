Gather.Views.Calendars.ProtocolFormView = Backbone.View.extend({
  initialize(options) {
    this.$('#calendars_protocol_kinds').trigger('change');
  },

  events: {
    'change #calendars_protocol_kinds': 'kindsChanged'
  },

  kindsChanged(event) {
    const kinds = this.$(event.target).val();
    this.$('.calendars_protocol_requires_kind').toggle(!kinds);
  }
});
