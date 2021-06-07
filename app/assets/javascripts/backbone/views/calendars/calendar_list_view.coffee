Gather.Views.Calendars.CalendarListView = Backbone.View.extend
  initialize: (options) ->
    @selection = options.selection || {}
    @resetSelection()

  events:
    'change input[type=checkbox]': 'checkboxChanged'
    'click .save-selection': 'saveLinkClicked'
    'click .reset-selection': 'resetLinkClicked'

  checkboxChanged: (e) ->
    e.stopPropagation()
    @$el.trigger('calendarSelectionChanged')

  selectedIds: ->
    @$("input[type=checkbox]:checked").map((_, el) -> el.value).get()

  saveLinkClicked: (e) ->
    e.preventDefault()
    @saveSelection()

  resetLinkClicked: (e) ->
    e.preventDefault()
    @resetSelection()
    @$el.trigger('calendarSelectionChanged')

  saveSelection: ->
    entries = @$("input[type=checkbox]").map((_, el) => [[el.value, @$(el).prop('checked')]])
    @selection = Object.fromEntries(entries)
    Gather.loadingIndicator.show()
    $.ajax
      url: '/users/update-setting'
      method: 'PATCH'
      contentType: 'application/json'
      data: JSON.stringify({settings: {calendar_selection: @selection}})
      success: -> Gather.loadingIndicator.hide()

  resetSelection: ->
    @$("input[type=checkbox]:checked").each((_, el) => @$(el).prop('checked', false))
    for id, checked of @selection
      @$("input[type=checkbox][value=#{id}]").prop('checked', checked)
