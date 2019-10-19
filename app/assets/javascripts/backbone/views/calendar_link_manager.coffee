Gather.Views.CalendarLinkManager = Backbone.View.extend
  initialize: (options) ->
    @calendarView = options.calendarView
    @baseUrl = options.baseUrl
    @listenTo(@calendarView, 'viewRender', @onViewRender.bind(this))

  onViewRender: ->
    @updatePermalink()

  updatePermalink: ->
    @$('#permalink').attr('href', @permalink())

  permalink: ->
    @baseUrl.replace("placeholder=xxx",
      "view=#{@calendarView.viewType()}&date=#{@calendarView.currentDate()}")
