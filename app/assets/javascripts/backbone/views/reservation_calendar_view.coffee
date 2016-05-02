Mess.Views.ReservationCalendarView = Backbone.View.extend

  URL_PARAMS_TO_VIEW_TYPES:
    'day': 'agendaDay'
    'week': 'agendaWeek'
    'month': 'month'

  initialize: (options) ->
    @newUrl = options.newUrl
    @calendar = @$('#calendar')

    @calendar.fullCalendar
      events: options.feedUrl,
      defaultView: @initialViewType(options.viewType)
      height: 700,
      allDaySlot: false,
      eventOverlap: false,
      selectable: true,
      selectOverlap: false,
      selectHelper: true,
      header: {
        left: 'title',
        center: 'agendaDay,agendaWeek,month',
        right: 'today prev,next'
      },
      select: @onSelect.bind(this),
      windowResize: @onWindowResize.bind(this),
      viewRender: @onViewRender.bind(this)

    @calendar.fullCalendar('gotoDate', moment(options.focusDate)) if options.focusDate

  events:
    'click .modal .btn-primary': 'create'

  onSelect: (start, end) ->
    @selection = { start: start.format(), end: end.format() }

    modal = @$('#create-confirm-modal')
    body = modal.find('.modal-body')
    if (start.format('YYYYMMDD') == end.format('YYYYMMDD'))
      date = start.format(Mess.TIME_FORMATS.regDate)
      startTime = start.format(Mess.TIME_FORMATS.regTime)
      endTime = end.format(Mess.TIME_FORMATS.regTime)
      body.html("Reserve on <b>#{date}</b> from <b>#{startTime}</b> to <b>#{endTime}</b>?")
    else
      startTime = start.format(Mess.TIME_FORMATS.fullDatetime)
      endTime = end.format(Mess.TIME_FORMATS.fullDatetime)
      body.html("Reserve from <b>#{startTime}</b> to <b>#{endTime}</b>?")

    modal.modal('show')

  onWindowResize: ->
    @setViewForWidth()

  onViewRender: ->
    @updatePermalink()

  updatePermalink: ->
    @$('#permalink').attr('href', @permalink())

  setViewForWidth: ->
    @calendar.fullCalendar('changeView', 'agendaDay') if @forceDay()

  forceDay: ->
    $(window).width() < 640

  create: ->
    window.location.href = "#{@newUrl}?#{$.param(@selection)}"

  initialViewType: (param) ->
    if @forceDay()
      'agendaDay'
    else
      @URL_PARAMS_TO_VIEW_TYPES[param] || 'agendaWeek'

  permalink: ->
    base = [location.protocol, '//', location.host, location.pathname].join('')
    view = @calendar.fullCalendar('getView')
    viewType = view.name.replace('agenda', '')
    date = view.intervalStart.format(Mess.TIME_FORMATS.compactDate)
    "#{base}?view=#{viewType}&date=#{date}"
