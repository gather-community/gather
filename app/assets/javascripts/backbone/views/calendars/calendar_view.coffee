# Ultimately this class should just wrap the calendar plugin and serve events.
# Most other heavy lifting should be done by other classes like CalendarLinkManager.
Gather.Views.Calendars.CalendarView = Backbone.View.extend

  URL_PARAMS_TO_VIEW_TYPES:
    'day': 'agendaDay'
    'week': 'agendaWeek'
    'month': 'month'

  initialize: (options) ->
    @newPath = options.newPath
    @feedPath = options.feedPath
    @viewParams = options.viewParams
    @defaultViewType = options.defaultViewType || 'week'
    @calendar = @$('#calendar')
    @ruleSet = options.ruleSet
    @canCreate = options.canCreate
    @calendarId = options.calendarId
    @allDayAllowed = options.allDayAllowed
    @allDayText = options.allDayText
    @showAppropriateEarlyLink()
    @initCalendar()

  events:
    'click .modal .btn-primary': 'create'
    'click .early': 'showHideEarly'

  initCalendar: ->
    @calendar.fullCalendar
      defaultView: @URL_PARAMS_TO_VIEW_TYPES[@viewParams.viewType || @defaultViewType]
      defaultDate: @viewParams.date
      height: 'auto'
      minTime: @minTime()
      allDaySlot: @allDayAllowed
      allDayText: @allDayText
      eventOverlap: @eventOverlap.bind(this)
      selectable: @canCreate
      selectOverlap: false
      selectHelper: true
      longPressDelay: 500
      header:
        left: 'title'
        center: 'agendaDay,agendaWeek,month'
        right: 'today prev,next'
      select: @onSelect.bind(this)
      loading: @onLoading.bind(this)
      eventDrop: @onEventChange.bind(this)
      eventResize: @onEventChange.bind(this)
      eventAfterAllRender: @onViewRender.bind(this)

  updateSource: (calendarIds) ->
    path = @feedPath
    if calendarIds
      url = new URL(path, 'https://example.com')
      url.searchParams.append('calendar_ids', calendarIds.join(' '))
      path = url.href.replace('https://example.com', '')
    oldSource = @calendar.fullCalendar('getEventSources')[0]
    @calendar.fullCalendar('addEventSource', path)
    @calendar.fullCalendar('removeEventSource', oldSource) if oldSource

  eventOverlap: (stillEvent, movingEvent) ->
    # Disallow overlap only if events on same calendar and the calendar forbids overlap
    stillEvent.calendarId != movingEvent.calendarId || stillEvent.calendarAllowsOverlap

  onSelect: (start, end, _, view) ->
    modal = @$('#create-confirm-modal')
    body = modal.find('.modal-body')
    changedInterval = false

    # If we get an all day selection (hasTime false), and the calendar supports all day events,
    # go with it. Else change to 12:00 - 13:00. This can happen if calendar is in month mode.
    # 12:00 - 13:00 works better with fixed times than 00:00 - 00:00.
    # We need to do this before applying fixed times so that overnight stays go from the day clicked
    # to the next day instead of ending on the day clicked.
    if !start.hasTime() && !@allDayAllowed
      start.hours(12)
      end.hours(13)
      end.days(end.days() - 1)

    [start, end, changed] = @applyFixedTimes(start, end)

    # Redraw selection if fixed times applied. But doing this in month mode causes an infinite loop
    # and doesn't provide any useful feedback to the user.
    if changed && view.name != "month"
      @calendar.fullCalendar('select', start, end)
      return

    # If there is an overlap we halt the process because overlaps aren't allowed.
    if @hasEventInInterval(start, end)
      @calendar.fullCalendar('unselect')
      return

    # Save for create method to use.
    @selection =
      start: start.format(Gather.TIME_FORMATS.machineDatetime)
      end: end.format(Gather.TIME_FORMATS.machineDatetime)

    # Build confirmation string
    end = end.subtract(1, 'seconds') unless start.hasTime()
    if (start.format('YYYYMMDD') == end.format('YYYYMMDD'))
      date = start.format(Gather.TIME_FORMATS.regDate)
      if start.hasTime()
        startTime = start.format(Gather.TIME_FORMATS.regTime)
        endTime = end.format(Gather.TIME_FORMATS.regTime)
        body.html("Create event on <b>#{date}</b> from <b>#{startTime}</b> to <b>#{endTime}</b>?")
      else
        body.html("Create event on <b>#{date}</b>?")
    else
      if start.hasTime()
        startTime = start.format(Gather.TIME_FORMATS.fullDatetime)
        endTime = end.format(Gather.TIME_FORMATS.fullDatetime)
      else
        startTime = start.format(Gather.TIME_FORMATS.regDate)
        endTime = end.format(Gather.TIME_FORMATS.regDate)
      body.html("Create event from <b>#{startTime}</b> to <b>#{endTime}</b>?")

    modal.modal('show')

  onViewRender: ->
    @$el.trigger('viewRender') # Notify other views
    @saveViewParams()

  onLoading: (isLoading) ->
    Gather.loadingIndicator.toggle(isLoading)

  onEventChange: (event, _, revertFunc) ->
    if !confirm("Are you sure you want to move the event '#{event.title}?'")
      revertFunc()
    else
      $.ajax
        url: "/calendars/events/#{event.id}"
        method: "POST"
        data:
          _method: "PATCH"
          calendars_event:
            starts_at: event.start.format()
            ends_at: event.end.format()
        error: (xhr) ->
          revertFunc()
          Gather.errorModal.modal('show').find('.modal-body').html(xhr.responseText)

  create: ->
    # Add start and end params to @newPath. The URL library needs a base url but we just want a path
    # so we add a base url and then remove it.
    url = new URL(@newPath, 'https://example.com')
    url.searchParams.append('start', @selection.start)
    url.searchParams.append('end', @selection.end)
    window.location.href = url.href.replace('https://example.com', '')

  minTime: ->
    if @viewParams.earlyMorning then '00:00:00' else '06:00:00'

  viewType: ->
    @calendar.fullCalendar('getView').name.replace('agenda', '').toLowerCase()

  date: ->
    @calendar.fullCalendar('getView').intervalStart.format(Gather.TIME_FORMATS.compactDate)

  hasEventInInterval: (start, end) ->
    matches = @calendar.fullCalendar 'clientEvents', (event) ->
      event.start.isBefore(end) && event.end.isAfter(start)
    matches.length > 0

  applyFixedTimes: (start, end) ->
    fixedStart = @ruleSet.fixedStartTime && $.fullCalendar.moment(@ruleSet.fixedStartTime)
    fixedEnd = @ruleSet.fixedEndTime && $.fullCalendar.moment(@ruleSet.fixedEndTime)
    changed = false

    if fixedStart && fixedStart.format('HHmm') != start.format('HHmm')
      start = @nearestFixedTime(start, fixedStart)
      length = end.diff(start)
      end = $.fullCalendar.moment(start).add(length)
      changed = true

    if fixedEnd && fixedEnd.format('HHmm') != end.format('HHmm')
      end = @nearestFixedTime(end, fixedEnd)
      changed = true

    end.add(1, 'day') if end.isBefore(start)

    [start, end, changed]

  # Gets the moment nearest to selectedTime with the hours and minutes of fixedTime.
  nearestFixedTime: (selectedTime, fixedTime) ->
    today = $.fullCalendar.moment(selectedTime)
    today.hours(fixedTime.hours()).minutes(fixedTime.minutes())

    if selectedTime.isBefore(today)
      nearest = $.fullCalendar.moment(today).subtract(1, 'day')
    else
      nearest = today

    nearest.add(1, 'days') if selectedTime.diff(nearest, 'hours', true) > 12

    nearest

  # Toggles the earlyMorning setting and re-renders.
  showHideEarly: (e) ->
    e.preventDefault()
    @viewParams.earlyMorning = !@viewParams.earlyMorning
    @showAppropriateEarlyLink()
    @calendar.fullCalendar('option', 'minTime', @minTime())
    @saveViewParams()

  showAppropriateEarlyLink: ->
    @$('#hide-early').css(display: if @viewParams.earlyMorning then 'inline' else 'none')
    @$('#show-early').css(display: if @viewParams.earlyMorning then 'none' else 'inline')

  expireCurrentDateSettingAfterOneHour: (settings) ->
    if settings.savedAt
      settingsAge = moment.duration(moment().diff(moment(settings.savedAt))).asSeconds()
      delete settings.date if settingsAge > 3600

  saveViewParams: ->
    $.ajax
      url: "/calendars/events/"
      method: "GET"
      data:
        update_lenses: 1
        view: @viewType()
        date: @date()
        early: @viewParams.earlyMorning
