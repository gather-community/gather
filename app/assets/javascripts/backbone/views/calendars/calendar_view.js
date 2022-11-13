/*
 * Ultimately this class should just wrap the calendar plugin and serve events.
 * Most other heavy lifting should be done by other classes like CalendarLinkManager.
 */
Gather.Views.Calendars.CalendarView = Backbone.View.extend({

  URL_PARAMS_TO_VIEW_TYPES: {
    "day": "agendaDay",
    "week": "agendaWeek",
    "month": "month"
  },

  initialize(options) {
    this.newPath = options.newPath;
    this.feedPath = options.feedPath;
    this.viewParams = options.viewParams;
    this.defaultViewType = options.defaultViewType || "week";
    this.calendar = this.$("#calendar");
    this.ruleSet = options.ruleSet;
    this.canCreate = options.canCreate;
    this.calendarId = options.calendarId;
    this.timedEventsOnly = options.timedEventsOnly;
    this.allDayText = options.allDayText;
    this.showAppropriateEarlyLink();
    this.initCalendar();
  },

  events: {
    "click .modal .btn-primary": "create",
    "click .early": "showHideEarly"
  },

  initCalendar() {
    return this.calendar.fullCalendar({
      defaultView: this.URL_PARAMS_TO_VIEW_TYPES[this.viewParams.viewType || this.defaultViewType],
      defaultDate: this.viewParams.date,
      height: "auto",
      minTime: this.minTime(),
      allDaySlot: !this.timedEventsOnly,
      allDayText: this.allDayText,
      selectOverlap: this.selectOverlap.bind(this),
      eventOverlap: this.eventOverlap.bind(this),
      selectable: this.canCreate,
      selectHelper: true,
      longPressDelay: 500,
      header: {
        left: "title",
        center: "agendaDay,agendaWeek,month",
        right: "today prev,next"
      },
      select: this.onSelect.bind(this),
      loading: this.onLoading.bind(this),
      eventDrop: this.onEventChange.bind(this),
      eventResize: this.onEventChange.bind(this),
      eventAfterAllRender: this.onViewRender.bind(this)
    });
  },

  updateSource(calendarIds) {
    let path = this.feedPath;
    if (calendarIds) {
      const url = new URL(path, "https://example.com");
      url.searchParams.append("calendar_ids", calendarIds.join(" "));
      path = url.href.replace("https://example.com", "");
    }
    const oldSource = this.calendar.fullCalendar("getEventSources")[0];
    this.calendar.fullCalendar("addEventSource", path);
    if (oldSource) {
      return this.calendar.fullCalendar("removeEventSource", oldSource);
    }
  },

  selectOverlap(existingEvent) {
    // Disallow overlap only if on single calendar page and overlap not allowed.
    return !this.calendarId || existingEvent.calendarAllowsOverlap;
  },

  eventOverlap(stillEvent, movingEvent) {
    // Disallow overlap only if events on same calendar and the calendar forbids overlap
    return (stillEvent.calendarId !== movingEvent.calendarId) || stillEvent.calendarAllowsOverlap;
  },

  onSelect(start, end, _, view) {
    let changed, endTime, startTime;
    const modal = this.$("#create-confirm-modal");
    const body = modal.find(".modal-body");
    const changedInterval = false;

    /*
     * If we get an all day selection (hasTime false), and the calendar supports all day events,
     * go with it. Else change to 12:00 - 13:00. This can happen if calendar is in month mode.
     * 12:00 - 13:00 works better with fixed times than 00:00 - 00:00.
     * We need to do this before applying fixed times so that overnight stays go from the day clicked
     * to the next day instead of ending on the day clicked.
     */
    if (!start.hasTime() && this.timedEventsOnly) {
      start.hours(12);
      end.hours(13);
      end.days(end.days() - 1);
    }

    [start, end, changed] = this.applyFixedTimes(start, end);

    /*
     * Redraw selection if fixed times applied. But doing this in month mode causes an infinite loop
     * and doesn't provide any useful feedback to the user.
     */
    if (changed && (view.name !== "month")) {
      this.calendar.fullCalendar("select", start, end);
      return;
    }

    // Save for create method to use.
    this.selection = {
      start: start.format(Gather.TIME_FORMATS.machineDatetime),
      end: end.format(Gather.TIME_FORMATS.machineDatetime)
    };

    // Build confirmation string
    if (!start.hasTime()) {
      end = end.subtract(1, "seconds");
    }
    if (start.format("YYYYMMDD") === end.format("YYYYMMDD")) {
      const date = start.format(Gather.TIME_FORMATS.regDate);
      if (start.hasTime()) {
        startTime = start.format(Gather.TIME_FORMATS.regTime);
        endTime = end.format(Gather.TIME_FORMATS.regTime);
        body.html(`Create event on <b>${date}</b> from <b>${startTime}</b> to <b>${endTime}</b>?`);
      } else {
        body.html(`Create event on <b>${date}</b>?`);
      }
    } else {
      if (start.hasTime()) {
        startTime = start.format(Gather.TIME_FORMATS.fullDatetime);
        endTime = end.format(Gather.TIME_FORMATS.fullDatetime);
      } else {
        startTime = start.format(Gather.TIME_FORMATS.regDate);
        endTime = end.format(Gather.TIME_FORMATS.regDate);
      }
      body.html(`Create event from <b>${startTime}</b> to <b>${endTime}</b>?`);
    }

    return modal.modal("show");
  },

  onViewRender() {
    this.$el.trigger("viewRender"); // Notify other views
    return this.saveViewParams();
  },

  onLoading(isLoading) {
    return Gather.loadingIndicator.toggle(isLoading);
  },

  onEventChange(event, _, revertFunc) {
    if (!confirm(`Are you sure you want to move the event '${event.title}?'`)) {
      return revertFunc();
    } else {
      return $.ajax({
        url: `/calendars/events/${event.id}`,
        method: "POST",
        data: {
          _method: "PATCH",
          calendars_event: {
            starts_at: event.start.format(),
            ends_at: event.end.format()
          }
        },
        error(xhr) {
          revertFunc();
          return Gather.errorModal.modal("show").find(".modal-body").html(xhr.responseText);
        }
      });
    }
  },

  create() {
    /*
     * Add start and end params to @newPath. The URL library needs a base url but we just want a path
     * so we add a base url and then remove it.
     */
    const url = new URL(this.newPath, "https://example.com");
    url.searchParams.append("start", this.selection.start);
    url.searchParams.append("end", this.selection.end);
    return window.location.href = url.href.replace("https://example.com", "");
  },

  minTime() {
    if (this.viewParams.earlyMorning) {
      return "00:00:00";
    } else {
      return "06:00:00";
    }
  },

  viewType() {
    return this.calendar.fullCalendar("getView").name.replace("agenda", "").toLowerCase();
  },

  date() {
    return this.calendar.fullCalendar("getView").intervalStart.format(Gather.TIME_FORMATS.compactDate);
  },

  hasEventInInterval(start, end) {
    const matches = this.calendar.fullCalendar("clientEvents", event => event.start.isBefore(end) && event.end.isAfter(start));
    return matches.length > 0;
  },

  applyFixedTimes(start, end) {
    const fixedStart = this.ruleSet.fixedStartTime && $.fullCalendar.moment(this.ruleSet.fixedStartTime);
    const fixedEnd = this.ruleSet.fixedEndTime && $.fullCalendar.moment(this.ruleSet.fixedEndTime);
    let changed = false;

    if (fixedStart && (fixedStart.format("HHmm") !== start.format("HHmm"))) {
      start = this.nearestFixedTime(start, fixedStart);
      const length = end.diff(start);
      end = $.fullCalendar.moment(start).add(length);
      changed = true;
    }

    if (fixedEnd && (fixedEnd.format("HHmm") !== end.format("HHmm"))) {
      end = this.nearestFixedTime(end, fixedEnd);
      changed = true;
    }

    if (end.isBefore(start)) {
      end.add(1, "day");
    }

    return [start, end, changed];
  },

  // Gets the moment nearest to selectedTime with the hours and minutes of fixedTime.
  nearestFixedTime(selectedTime, fixedTime) {
    let nearest;
    const today = $.fullCalendar.moment(selectedTime);
    today.hours(fixedTime.hours()).minutes(fixedTime.minutes());

    if (selectedTime.isBefore(today)) {
      nearest = $.fullCalendar.moment(today).subtract(1, "day");
    } else {
      nearest = today;
    }

    if (selectedTime.diff(nearest, "hours", true) > 12) {
      nearest.add(1, "days");
    }

    return nearest;
  },

  // Toggles the earlyMorning setting and re-renders.
  showHideEarly(e) {
    e.preventDefault();
    this.viewParams.earlyMorning = !this.viewParams.earlyMorning;
    this.showAppropriateEarlyLink();
    this.calendar.fullCalendar("option", "minTime", this.minTime());
    return this.saveViewParams();
  },

  showAppropriateEarlyLink() {
    this.$("#hide-early").css({display: this.viewParams.earlyMorning ? "inline" : "none"});
    return this.$("#show-early").css({display: this.viewParams.earlyMorning ? "none" : "inline"});
  },

  expireCurrentDateSettingAfterOneHour(settings) {
    if (settings.savedAt) {
      const settingsAge = moment.duration(moment().diff(moment(settings.savedAt))).asSeconds();
      if (settingsAge > 3600) {
        return delete settings.date;
      }
    }
  },

  saveViewParams() {
    return $.ajax({
      url: "/calendars/events/",
      method: "GET",
      data: {
        update_lenses: 1,
        view: this.viewType(),
        date: this.date(),
        early: this.viewParams.earlyMorning
      }
    });
  }
});
