Gather.Views.Calendars.CalendarListView = Backbone.View.extend
  initialize: (options) ->

  events:
    'change input[type=checkbox]': 'checkboxChanged'

  checkboxChanged: (e) ->
    e.stopPropagation()
    @$el.trigger('calendarSelectionChanged')

  selectedIds: ->
    @$("input[type=checkbox]:checked").map(-> @value).get()
