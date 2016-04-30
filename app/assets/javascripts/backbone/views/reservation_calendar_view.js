Mess.Views.ReservationCalendarView = Backbone.View.extend({

  initialize: function(options) {
    this.$el.fullCalendar({
      events: options.feed_url,
      defaultView: 'agendaWeek',
      allDaySlot: false,
      eventOverlap: false,
      selectable: true,
      selectOverlap: false,
      selectHelper: true,
      header: {
        left: 'title',
        center: 'agendaDay,agendaWeek,month',
        right: 'today prev,next'
      }
    });
  }

});
