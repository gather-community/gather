Mess.Views.ReservationCalendarView = Backbone.View.extend

  initialize: (options) ->
    @newUrl = options.newUrl
    @calendar = @$('#calendar')

    @calendar.fullCalendar
      events: options.feedUrl,
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
      },
      select: @onSelect.bind(this)

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

  create: ->
    window.location.href = "#{@newUrl}?#{$.param(@selection)}"
