Gather.Views.Calendars.CalendarListView = Backbone.View.extend
  initialize: (options) ->
    @selection = options.selection || []
    @resetSelection()

  events:
    'change input[type=checkbox]': 'checkboxChanged'
    'click .save-selection': 'saveLinkClicked'
    'click .reset-selection': 'resetLinkClicked'

  checkboxChanged: (e) ->
    e.stopPropagation()
    @$el.trigger('calendarSelectionChanged')

  selectedIds: ->
    @$("input[type=checkbox]:checked").map(-> parseInt(@value)).get()

  saveLinkClicked: (e) ->
    e.preventDefault()
    @saveSelection()

  resetLinkClicked: (e) ->
    e.preventDefault()
    @resetSelection()
    @$el.trigger('calendarSelectionChanged')

  saveSelection: ->
    @selection = @selectedIds()
    $.ajax
      url: '/users/update-setting'
      method: 'PATCH'
      contentType: 'application/json'
      data: JSON.stringify({settings: {calendar_selection: @selection}})

  resetSelection: ->
    @$("input[type=checkbox]:checked").each(-> $(this).prop('checked', false))
    @selection.forEach((id) -> @$("input[type=checkbox][value=#{id}]").prop('checked', true))
