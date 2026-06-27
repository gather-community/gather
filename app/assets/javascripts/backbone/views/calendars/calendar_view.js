/*
 * Ultimately this class should just wrap the calendar plugin and serve events.
 * Most other heavy lifting should be done by other classes like CalendarLinkManager.
 */
Gather.Views.Calendars.CalendarView = Backbone.View.extend({
  URL_PARAMS_TO_VIEW_TYPES: {
    day: "agendaDay",
    week: "agendaWeek",
    month: "month",
  },

  initialize(options) {
    this.newPath = options.newPath;
    this.feedPath = options.feedPath;
    this.viewParams = options.viewParams;
    this.defaultViewType = options.defaultViewType || "week";
    this.calendar = this.$("#calendar");
    this.liveRegion = this.$("#calendar-live-region");
    this.ruleSet = options.ruleSet;
    this.canCreate = options.canCreate;
    this.calendarId = options.calendarId;
    this.timedEventsOnly = options.timedEventsOnly;
    this.allDayText = options.allDayText;
    this._fcHeaderLastFocusKey = null;
    this._fcGridFocusDate = null;
    this._fcGridShouldFocus = false;
    this._calendarLiveRegionText = null;
    this.showAppropriateEarlyLink();
    this.initCalendar();
  },

  events() {
    const headerControlSelector =
      "#calendar .fc-toolbar button, " +
      "#calendar .fc-header button, " +
      "#calendar .fc-toolbar a, " +
      "#calendar .fc-header a";

    return {
      "click .modal .btn-primary": "create",
      "click .early": "showHideEarly",
      "click .fc-day[data-date]": "onGridCellClick",
      "focusin .fc-day[data-date]": "onGridCellFocusIn",
      "focusin .fc-event": "onGridEventFocusIn",
      "keydown .fc-day[data-date]": "onGridCellKeydown",
      "keydown .fc-event": "onGridEventKeydown",

      /*
       * Capture header interactions before FullCalendar handles them, so we can restore focus
       * after the header re-renders (navigation/view changes).
       */
      [`focusin ${headerControlSelector}`]: "captureHeaderControlActivation",
      [`mousedown ${headerControlSelector}`]: "captureHeaderControlActivation",
      [`keydown ${headerControlSelector}`]:
        "captureHeaderControlActivationOnKeydown",
    };
  },

  initCalendar() {
    this.calendar.fullCalendar({
      defaultView:
        this.URL_PARAMS_TO_VIEW_TYPES[
          this.viewParams.viewType || this.defaultViewType
        ],
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
        right: "today prev,next",
      },
      select: this.onSelect.bind(this),
      loading: this.onLoading.bind(this),
      eventDrop: this.onEventChange.bind(this),
      eventResize: this.onEventChange.bind(this),
      viewRender: this.updateCalendarLiveRegion.bind(this),
      eventAfterAllRender: this.onViewRender.bind(this),
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
      this.calendar.fullCalendar("removeEventSource", oldSource);
    }
  },

  selectOverlap(existingEvent) {
    // Disallow overlap only if on single calendar page and overlap not allowed.
    return !this.calendarId || existingEvent.calendarAllowsOverlap;
  },

  eventOverlap(stillEvent, movingEvent) {
    // Disallow overlap only if events on same calendar and the calendar forbids overlap
    return (
      stillEvent.calendarId !== movingEvent.calendarId ||
      stillEvent.calendarAllowsOverlap
    );
  },

  onSelect(start, end, _, view) {
    let changed, endTime, startTime;
    const modal = this.$("#create-confirm-modal");
    const body = modal.find(".modal-body");

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
    if (changed && view.name !== "month") {
      this.calendar.fullCalendar("select", start, end);
      return;
    }

    // Save for create method to use.
    this.selection = {
      start: start.format(Gather.TIME_FORMATS.machineDatetime),
      end: end.format(Gather.TIME_FORMATS.machineDatetime),
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

    modal.modal("show");
  },

  onViewRender() {
    this.applyFullCalendarHeaderA11y();
    this.applyFullCalendarGridA11y();
    this.updateCalendarLiveRegion();
    this.$el.trigger("viewRender"); // Notify other views
  },

  updateCalendarLiveRegion() {
    const view = this.calendar.fullCalendar("getView");
    if (!this.liveRegion.length) {
      return;
    }

    if (!view || view.name !== "month") {
      this.liveRegion.text("");
      this._calendarLiveRegionText = null;
      return;
    }

    const message = `Calendar now showing ${view.intervalStart.format("MMMM YYYY")}`;
    if (message !== this._calendarLiveRegionText) {
      this.liveRegion.text(message);
      this._calendarLiveRegionText = message;
    }
  },

  captureHeaderControlActivation(e) {
    const helper = Gather.Utils && Gather.Utils.FullCalendarHeaderA11y;
    if (!helper || !helper.focusKeyFromElement) {
      return;
    }

    const key = helper.focusKeyFromElement(e.currentTarget);
    if (key) {
      this._fcHeaderLastFocusKey = key;
    }
  },

  captureHeaderControlActivationOnKeydown(e) {
    const keyCode = e.which || e.keyCode;
    const isActivationKey = keyCode === 13 || keyCode === 32; // Enter or Space
    if (!isActivationKey) {
      return;
    }
    const helper = Gather.Utils && Gather.Utils.FullCalendarHeaderA11y;
    const key = helper && helper.focusKeyFromElement && helper.focusKeyFromElement(e.currentTarget);
    if (this.isViewControlKey(key)) {
      this._fcHeaderLastFocusKey = null;
      this._fcGridFocusDate = null;
      this._fcGridShouldFocus = true;
      setTimeout(() => this.focusGridAfterViewControlActivation(), 0);
      return;
    }
    this.captureHeaderControlActivation(e);
  },

  isViewControlKey(key) {
    return Object.keys(this.URL_PARAMS_TO_VIEW_TYPES)
      .some((viewType) => this.URL_PARAMS_TO_VIEW_TYPES[viewType] === key);
  },

  focusGridAfterViewControlActivation() {
    if (this._fcGridShouldFocus) {
      this.applyFullCalendarGridKeyboard();
    }
  },

  applyFullCalendarHeaderA11y() {
    const helper = Gather.Utils && Gather.Utils.FullCalendarHeaderA11y;
    if (!helper || !helper.enhance) {
      return;
    }

    const focusKeyToRestore = this._fcHeaderLastFocusKey;
    helper.enhance(this.calendar, {
      toolbarLabel: "Calendar controls",
      focusKeyToRestore,
    });

    // Always clear after attempting restore to avoid stealing focus on later renders.
    if (focusKeyToRestore) {
      this._fcHeaderLastFocusKey = null;
    }
  },

  applyFullCalendarGridA11y() {
    const view = this.calendar.fullCalendar("getView");
    if (!view) {
      return;
    }

    /*
     * FullCalendar uses nested layout tables; mark wrappers presentational
     * so screen readers announce the grid model instead of table boundaries.
     */
    this.calendar.find(".fc-view > table").attr("role", "presentation");
    this.applyFullCalendarGridDateLabels();

    if (view.name === "month") {
      const $grid = this.calendar.find(".fc-month-view").first();
      if (!$grid.length) {
        return;
      }
      $grid.attr("role", "grid");
      $grid.find(".fc-row").attr("role", "row");
      $grid.find(".fc-day").attr("role", "gridcell");
      $grid.find(".fc-row table").attr("role", "presentation");
      this.applyFullCalendarGridKeyboard();
      return;
    }

    if (view.name === "agendaDay" || view.name === "agendaWeek") {
      const $allDayGrid = this.calendar.find(".fc-agenda-view .fc-day-grid").first();
      if ($allDayGrid.length) {
        $allDayGrid.attr("role", "grid");
        $allDayGrid.find(".fc-row").attr("role", "row");
        $allDayGrid.find(".fc-day").attr("role", "gridcell");
        $allDayGrid.find(".fc-row table").attr("role", "presentation");
      }

      const $timeGrid = this.calendar.find(".fc-time-grid").first();
      if ($timeGrid.length) {
        $timeGrid.attr("role", "grid");
        $timeGrid.find(".fc-slats tr").attr("role", "row");
        $timeGrid.find(".fc-slats td").attr("role", "gridcell");
        $timeGrid.find("table").attr("role", "presentation");
      }

      this.applyFullCalendarGridKeyboard();
    }
  },

  applyFullCalendarGridDateLabels() {
    this.calendar.find(".fc-bg .fc-day[data-date]:visible").each((_, cell) => {
      const $cell = $(cell);
      const dateString = $cell.attr("data-date");
      const date = $.fullCalendar.moment(dateString, "YYYY-MM-DD");

      if (date.isValid()) {
        $cell.attr("aria-label", date.format("dddd, MMMM D, YYYY"));
      }
    });
  },

  applyFullCalendarGridKeyboard() {
    const view = this.calendar.fullCalendar("getView");
    if (!view) {
      return;
    }

    // Keep grid entry/exit on date cells only so Shift+Tab can leave naturally.
    this.calendar.find(".fc-view").removeAttr("tabindex");
    const today = $.fullCalendar.moment();
    let focusDate = this._fcGridFocusDate;

    if (!focusDate) {
      if (this.getGridDayCell(today).length) {
        focusDate = today.format("YYYY-MM-DD");
      } else {
        focusDate = view.intervalStart.format("YYYY-MM-DD");
      }
    }

    this.setGridFocus(focusDate, {focus: this._fcGridShouldFocus});
    this._fcGridShouldFocus = false;
  },

  onGridCellClick(e) {
    const date = this.gridDateFromCell($(e.currentTarget));
    if (!date) {
      return;
    }
    this.setGridFocus(date, {focus: false});
  },

  onGridCellFocusIn(e) {
    const date = this.gridDateFromCell($(e.currentTarget));
    if (!date) {
      return;
    }
    this.setGridFocus(date, {focus: false});
  },

  onGridCellKeydown(e) {
    const keyCode = e.which || e.keyCode;
    const date = this.gridDateFromCell($(e.currentTarget));
    if (!date) {
      return;
    }

    let nextDate = null;
    if (keyCode === 37) {
      nextDate = date.clone().add(-1, "day");
    } else if (keyCode === 39) {
      nextDate = date.clone().add(1, "day");
    } else if (keyCode === 38) {
      nextDate = date.clone().add(-1, "week");
    } else if (keyCode === 40) {
      nextDate = date.clone().add(1, "week");
    } else if (keyCode === 36) {
      nextDate = date.clone().startOf("week");
    } else if (keyCode === 35) {
      nextDate = date.clone().endOf("week").startOf("day");
    } else if (keyCode === 33) {
      nextDate = date.clone().add(-1, "month");
    } else if (keyCode === 34) {
      nextDate = date.clone().add(1, "month");
    } else if (keyCode === 13 || keyCode === 32) {
      this.selectDateFromGrid(date);
      e.preventDefault();
      return;
    } else {
      return;
    }

    this.moveGridFocusToDate(nextDate);
    e.preventDefault();
  },

  onGridEventFocusIn(e) {
    const date = this.resolveGridDateFromElement($(e.currentTarget));
    if (!date) {
      return;
    }
    this.setGridFocus(date, {focus: false});
  },

  onGridEventKeydown(e) {
    const keyCode = e.which || e.keyCode;
    const isNavigationKey =
      keyCode === 37 ||
      keyCode === 38 ||
      keyCode === 39 ||
      keyCode === 40 ||
      keyCode === 33 ||
      keyCode === 34 ||
      keyCode === 35 ||
      keyCode === 36;
    if (!isNavigationKey) {
      return;
    }

    const date = this.resolveGridDateFromElement($(e.currentTarget));
    if (!date) {
      return;
    }

    let nextDate = null;
    if (keyCode === 37) {
      nextDate = date.clone().add(-1, "day");
    } else if (keyCode === 39) {
      nextDate = date.clone().add(1, "day");
    } else if (keyCode === 38) {
      nextDate = date.clone().add(-1, "week");
    } else if (keyCode === 40) {
      nextDate = date.clone().add(1, "week");
    } else if (keyCode === 36) {
      nextDate = date.clone().startOf("week");
    } else if (keyCode === 35) {
      nextDate = date.clone().endOf("week").startOf("day");
    } else if (keyCode === 33) {
      nextDate = date.clone().add(-1, "month");
    } else if (keyCode === 34) {
      nextDate = date.clone().add(1, "month");
    }

    if (nextDate) {
      this.moveGridFocusToDate(nextDate);
      e.preventDefault();
      e.stopPropagation();
    }
  },

  selectDateFromGrid(date) {
    if (!this.canCreate) {
      return;
    }
    const start = date.clone().startOf("day");
    const end = date.clone().add(1, "day").startOf("day");
    this.calendar.fullCalendar("select", start, end);
  },

  moveGridFocusToDate(date) {
    const dateString = date.format("YYYY-MM-DD");
    this._fcGridFocusDate = dateString;

    if (this.getGridDayCell(date).length) {
      this.setGridFocus(dateString, {focus: true});
      return;
    }

    this._fcGridShouldFocus = true;
    this.calendar.fullCalendar("gotoDate", date);
  },

  setGridFocus(date, options) {
    const dateString = typeof date === "string" ? date : date.format("YYYY-MM-DD");
    const $cells = this.getNavigableGridCells();
    const $target = this.getGridDayCell(dateString);
    if (!$target.length) {
      return false;
    }

    $cells.attr("tabindex", "-1");
    $cells.removeClass("fc-gather-grid-active");
    $target.attr("tabindex", "0");
    $target.addClass("fc-gather-grid-active");
    this.updateGridCellAriaStates(dateString);
    if (options && options.focus) {
      $target.focus();
    }
    this._fcGridFocusDate = dateString;
    return true;
  },

  updateGridCellAriaStates(selectedDateString) {
    const todayString = $.fullCalendar.moment().format("YYYY-MM-DD");
    const $cells = this.getNavigableGridCells();

    $cells.each((_, cell) => {
      const $cell = $(cell);
      const dateString = $cell.attr("data-date");
      const isSelected = dateString === selectedDateString;
      const isToday = dateString === todayString;

      $cell.attr("aria-selected", isSelected ? "true" : "false");
      if (isToday) {
        $cell.attr("aria-current", "date");
      } else {
        $cell.removeAttr("aria-current");
      }
    });
  },

  getGridDayCell(date) {
    const dateString = typeof date === "string" ? date : date.format("YYYY-MM-DD");
    return this.getNavigableGridCells()
      .filter((_, el) => $(el).attr("data-date") === dateString)
      .first();
  },

  getNavigableGridCells() {
    const view = this.calendar.fullCalendar("getView");
    if (!view) {
      return this.calendar.find(".fc-day[data-date]");
    }

    if (view.name === "month") {
      return this.calendar.find(".fc-month-view .fc-day[data-date]:visible");
    }

    const $allDayCells = this.calendar.find(".fc-agenda-view .fc-day-grid .fc-day[data-date]:visible");
    if ($allDayCells.length) {
      return $allDayCells;
    }

    return this.calendar.find(".fc-time-grid .fc-bg .fc-day[data-date]:visible");
  },

  gridDateFromCell($cell) {
    const dateString = $cell.data("date") || $cell.attr("data-date");
    if (!dateString) {
      return null;
    }
    return $.fullCalendar.moment(dateString, "YYYY-MM-DD");
  },

  resolveGridDateFromElement($element) {
    const $dateContainer = $element.closest("[data-date]");
    const date = this.gridDateFromCell($dateContainer);
    if (date) {
      return date;
    }

    if (this._fcGridFocusDate) {
      return $.fullCalendar.moment(this._fcGridFocusDate, "YYYY-MM-DD");
    }

    const view = this.calendar.fullCalendar("getView");
    if (view && view.intervalStart) {
      return view.intervalStart.clone().startOf("day");
    }

    return null;
  },

  onLoading(isLoading) {
    Gather.loadingIndicator.toggle(isLoading);
  },

  onEventChange(event, _, revertFunc) {
    window.Modal.confirmModal(`Are you sure you want to move the event '${event.title}?'`).then(ok => {
      if (!ok) {
        revertFunc();
        return;
      }
      $.ajax({
        // The feed is eventlet-centric (event.id is the eventlet id); the update endpoint wants event id.
        url: `/calendars/events/${event.eventId}`,
        method: "POST",
        data: {
          _method: "PATCH",
          calendars_event: {
            starts_at: event.start.format(),
            ends_at: event.end.format(),
          },
        },
        error(xhr) {
          revertFunc();
          window.Modal.alertModal(xhr.responseText, {title: "Error", label: "Close"});
        },
      });
    });
  },

  create() {
    /*
     * Add start and end params to @newPath. The URL library needs a base url but we just want a path
     * so we add a base url and then remove it.
     */
    const url = new URL(this.newPath, "https://example.com");
    url.searchParams.append("start", this.selection.start);
    url.searchParams.append("end", this.selection.end);
    window.location.href = url.href.replace("https://example.com", "");
  },

  minTime() {
    if (this.viewParams.earlyMorning) {
      return "00:00:00";
    } else {
      return "06:00:00";
    }
  },

  viewType() {
    return this.calendar
      .fullCalendar("getView")
      .name.replace("agenda", "")
      .toLowerCase();
  },

  date() {
    return this.calendar
      .fullCalendar("getView")
      .intervalStart.format(Gather.TIME_FORMATS.compactDate);
  },

  // Navigate to the given URL-style view param and date string, falling back to the
  // current view/initial date if either is absent (e.g. when restoring a history entry
  // that pre-dates any URL params being set).
  navigateTo(urlViewParam, dateParam) {
    const viewType = this.URL_PARAMS_TO_VIEW_TYPES[urlViewParam] ||
      this.calendar.fullCalendar("getView").name;
    const date = dateParam || this.viewParams.date;
    this.calendar.fullCalendar("changeView", viewType, date);
  },

  hasEventInInterval(start, end) {
    const matches = this.calendar.fullCalendar(
      "clientEvents",
      (event) => event.start.isBefore(end) && event.end.isAfter(start)
    );
    return matches.length > 0;
  },

  applyFixedTimes(start, end) {
    const fixedStart =
      this.ruleSet.fixedStartTime &&
      $.fullCalendar.moment(this.ruleSet.fixedStartTime);
    const fixedEnd =
      this.ruleSet.fixedEndTime &&
      $.fullCalendar.moment(this.ruleSet.fixedEndTime);
    let changed = false;

    if (fixedStart && fixedStart.format("HHmm") !== start.format("HHmm")) {
      start = this.nearestFixedTime(start, fixedStart);
      const length = end.diff(start);
      end = $.fullCalendar.moment(start).add(length);
      changed = true;
    }

    if (fixedEnd && fixedEnd.format("HHmm") !== end.format("HHmm")) {
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
    // Explicitly notify the link manager; minTime changes don't always re-fire
    // eventAfterAllRender since FullCalendar may skip the event rendering pipeline.
    this.$el.trigger("viewRender");
  },

  showAppropriateEarlyLink() {
    this.$("#hide-early").css({
      display: this.viewParams.earlyMorning ? "inline" : "none",
    });
    this.$("#show-early").css({
      display: this.viewParams.earlyMorning ? "none" : "inline",
    });
  },

});

