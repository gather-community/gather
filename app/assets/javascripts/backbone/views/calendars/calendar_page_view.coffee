Gather.Views.Calendars.CalendarPageView = Backbone.View.extend
  initialize: (options) ->
    @calendarView = options.calendarView
    @listView = options.listView
    @linkManager = options.linkManager

  events:
    'viewRender': 'onViewRender'

  onViewRender: ->
    @linkManager.update(@calendarView.viewType(), @calendarView.currentDate())
