Gather.Views.Calendars.CalendarListView = Backbone.View.extend
  initialize: (options) ->
    @selection = options.selection || {}
    @dontPersist = options.dontPersist || false
    @loadSelection()

  events:
    'change input[type=checkbox]': 'checkboxChanged'

  checkboxChanged: (e) ->
    e.stopPropagation()
    @$el.trigger('calendarSelectionChanged')
    @saveSelection()

  selectedIds: ->
    @$("input[type=checkbox]:checked").map((_, el) -> el.value).get()

  allSelected: ->
    @$("input[type=checkbox]").get().every((el) => @$(el).is(":checked"))

  saveSelection: ->
    return if @dontPersist
    entries = @$("input[type=checkbox]").map((_, el) => [[el.value, @$(el).prop('checked')]])
    @selection = Object.fromEntries(entries)
    Gather.loadingIndicator.show()
    $.ajax
      url: '/users/update-setting'
      method: 'PATCH'
      contentType: 'application/json'
      data: JSON.stringify({settings: {calendar_selection: @selection}})
      success: -> Gather.loadingIndicator.hide()

  loadSelection: ->
    @$("input[type=checkbox]:checked").each((_, el) => @$(el).prop('checked', false))
    for id, checked of @selection
      @$("input[type=checkbox][value=#{id}]").prop('checked', checked)
