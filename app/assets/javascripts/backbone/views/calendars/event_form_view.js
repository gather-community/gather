Gather.Views.Calendars.EventFormView = Backbone.View.extend({
  initialize(options) {
    this.origDatePickerFormat = this.$('.datetimepicker input').data('dateOptions').format;
    this.$('#calendars_event_kind').trigger('change');
    this.$('#calendars_event_all_day').trigger('change');
  },

  events: {
    'change #calendars_event_kind': 'kindChanged',
    'change #calendars_event_all_day': 'allDayChanged'
  },

  kindChanged(event) {
    const kind = this.$(event.target).val();
    this.$(".calendars_event_pre_notice[data-kinds]").hide();
    this.$(`.calendars_event_pre_notice[data-kinds*=\"{${kind}}\"]`).show();
  },

  allDayChanged(event) {
    const allDay = this.$(event.target).prop('checked');

    // Remove everything after the h: (the time portion) if in all day mode
    const format = allDay ? this.origDatePickerFormat.replace(/ h:.*$/i, '') : this.origDatePickerFormat;
    this.$('.datetimepicker').each((_, el) => {
      this.$(el).data('DateTimePicker').format(format);
    });
  }
});
