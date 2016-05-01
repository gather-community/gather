Mess.Views.ReservationCalendarView = Backbone.View.extend

  initialize: (options) ->
    @newUrl = options.newUrl
    @calendar = @$('#calendar')

    @calendar.fullCalendar
      events: options.feedUrl,
      defaultView: if @forceDay() then 'agendaDay' else 'agendaWeek',
      height: 500,
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
      windowResize: @onWindowResize.bind(this)

    @calendar.fullCalendar('gotoDate', moment(options.focusDate)) if options.focusDate

  events:
    'click .modal .btn-primary': 'create'

  onSelect: (start, end) ->
    @selection = { start: start.format(), end: end.format() }

    modal = @$('#create-confirm-modal')
    body = modal.find('.modal-body')
    if (start.format('YYYYMMDD') == end.format('YYYYMMDD'))
      date = start.format(Mess.timeFormats.regDate)
      startTime = start.format(Mess.timeFormats.regTime)
      endTime = end.format(Mess.timeFormats.regTime)
      body.html("Reserve on <b>#{date}</b> from <b>#{startTime}</b> to <b>#{endTime}</b>?")
    else
      startTime = start.format(Mess.timeFormats.fullDatetime)
      endTime = end.format(Mess.timeFormats.fullDatetime)
      body.html("Reserve from <b>#{startTime}</b> to <b>#{endTime}</b>?")

    modal.modal('show')

  onWindowResize: ->
    @setViewForWidth()

  setViewForWidth: ->
    @calendar.fullCalendar('changeView', 'agendaDay') if @forceDay()

  forceDay: ->
    $(window).width() < 640

  create: ->
    window.location.href = "#{@newUrl}?#{$.param(@selection)}"
