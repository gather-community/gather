Gather.Views.Calendars.CalendarPageView = Backbone.View.extend
  initialize: (options) ->
    @pageType = options.pageType
    @calendarView = options.calendarView
    @calendarId = options.calendarId
    @listView = options.listView
    @linkManager = options.linkManager
    @updateCalendarSource()

  events:
    'viewRender': 'onViewRender'
    'calendarSelectionChanged': 'updateCalendarSource'

  onViewRender: ->
    @linkManager.update(@calendarView.viewType(), @calendarView.currentDate())

  updateCalendarSource: ->
    calendarIds = null
    calendarIds = @listView.selectedIds() if @pageType == 'combined'
    calendarIds = [@calendarId] if @pageType == 'single'
    @calendarView.updateSource(calendarIds)
