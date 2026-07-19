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
    this.gridFocusLiveRegion = this.$("#calendar-grid-focus-live-region");
    this.ruleSet = options.ruleSet;
    this.canCreate = options.canCreate;
    this.calendarId = options.calendarId;
    this.timedEventsOnly = options.timedEventsOnly;
    this.allDayText = options.allDayText;
    this._fcHeaderLastFocusKey = null;
    this._fcGridFocusDate = null;
    this._fcGridFocusTime = null;
    this._fcGridShouldFocus = false;
    this._fcGridHideSlotsTimer = null;
    this._fcPreservedGridCell = null;
    this._fcPreservedGridCellFinalLabel = null;
    this._fcPreservedGridCellLiveAnnouncement = null;
    this._fcGridFocusAnnouncementTimer = null;
    this._calendarLiveRegionText = null;
    this._renderedEventDateKeys = {};
    this._renderedEventRangesByKey = {};
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
      "click .fc-day[data-date], .fc-gather-time-slot": "onGridCellClick",
      "focusin .fc-day[data-date], .fc-gather-time-slot": "onGridCellFocusIn",
      "focusout .fc-day[data-date], .fc-gather-time-slot": "onGridCellFocusOut",
      "focusin .fc-event": "onGridEventFocusIn",
      "keydown .fc-day[data-date], .fc-gather-time-slot": "onGridCellKeydown",
      "keydown .fc-event": "onGridEventKeydown",

      /*
       * Capture header interactions before FullCalendar handles them, so we can restore focus
       * after the header re-renders (navigation/view changes).
       */
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
      viewRender: () => {
        this.resetRenderedEventCounts();
        this.updateCalendarLiveRegion({includeEmptyState: false});
      },
      eventAfterRender: this.trackRenderedEventCount.bind(this),
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

    this.showCreateConfirmModal(modal);
  },

  showCreateConfirmModal(modal) {
    const returnFocusTo = document.activeElement;
    const focusCancel = () => modal.find(".btn-default").first().focus();
    const closeOnEscape = (e) => {
      if ((e.which || e.keyCode) === 27) {
        modal.modal("hide");
        e.preventDefault();
        e.stopPropagation();
      }
    };

    modal.off(".calendarCreateFocus");
    $(document).off("keydown.calendarCreateFocus");
    modal.on("shown.bs.modal.calendarCreateFocus", () => {
      focusCancel();
      setTimeout(focusCancel, 50);
      setTimeout(focusCancel, 150);
    });
    modal.on("keydown.calendarCreateFocus", closeOnEscape);
    $(document).on("keydown.calendarCreateFocus", closeOnEscape);
    modal.on("hidden.bs.modal.calendarCreateFocus", () => {
      modal.off(".calendarCreateFocus");
      $(document).off("keydown.calendarCreateFocus");
      this.calendar.fullCalendar("unselect");
      if (returnFocusTo && document.contains(returnFocusTo)) {
        setTimeout(() => returnFocusTo.focus(), 0);
      }
    });
    modal.modal({keyboard: true, show: true});
  },

  onViewRender() {
    this.applyFullCalendarHeaderA11y();
    this.applyFullCalendarGridA11y();
    this.updateCalendarLiveRegion();
    this.$el.trigger("viewRender"); // Notify other views
  },

  updateCalendarLiveRegion(options) {
    const view = this.calendar.fullCalendar("getView");
    if (!this.liveRegion.length) {
      return;
    }

    if (!view) {
      this.liveRegion.text("");
      this._calendarLiveRegionText = null;
      return;
    }

    const message = this.calendarLiveRegionMessage(view, options || {});
    if (message !== this._calendarLiveRegionText) {
      this.liveRegion.text(message);
      this._calendarLiveRegionText = message;
    }
  },

  calendarLiveRegionMessage(view, options) {
    const messageParts = [];
    if (view.name === "month") {
      messageParts.push(`Calendar now showing ${view.intervalStart.format("MMMM YYYY")}`);
    }

    if (
      options.includeEmptyState !== false &&
      (view.name === "agendaWeek" || view.name === "month")
    ) {
      const eventCount = this.renderedEventCountInInterval(view.intervalStart, view.intervalEnd);
      messageParts.push(`${this.eventCountLabel(eventCount)} ${this.eventCountPeriodForView(view)}`);
    }

    return messageParts.join(". ");
  },

  eventCountPeriodForView(view) {
    if (view.name === "agendaWeek") {
      return "this week";
    } else {
      return "this month";
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
      this._fcGridFocusTime = null;
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
      $grid.attr({
        role: "grid",
        "aria-label": "Month calendar",
      });
      $grid.find(".fc-row").attr("role", "row");
      $grid.find(".fc-day").attr("role", "gridcell");
      $grid.find(".fc-row table").attr("role", "presentation");
      this.applyFullCalendarGridKeyboard();
      return;
    }

    if (view.name === "agendaDay" || view.name === "agendaWeek") {
      /*
       * One named grid for all-day + timed slots. Separate nested role="grid"
       * regions (especially an unlabeled time grid) become empty "browse mode"
       * stops when Tab leaves the all-day row.
       */
      const $agenda = this.calendar.find(".fc-agenda-view").first();
      if ($agenda.length) {
        $agenda.attr({
          role: "grid",
          "aria-label": this.agendaGridLabel(view),
        });
        // FullCalendar's visual divider is decorative and otherwise announced as "separator".
        $agenda.find(".fc-divider").attr("aria-hidden", "true");
      }

      const $allDayGrid = this.calendar.find(".fc-agenda-view .fc-day-grid").first();
      if ($allDayGrid.length) {
        $allDayGrid.attr("role", "presentation");
        $allDayGrid.find(".fc-row").attr("role", "row");
        $allDayGrid.find(".fc-day").attr("role", "gridcell");
        $allDayGrid.find(".fc-row table").attr("role", "presentation");
      }

      const $timeGrid = this.calendar.find(".fc-time-grid").first();
      if ($timeGrid.length) {
        $timeGrid.attr("role", "presentation");
        $timeGrid.find("table").attr("role", "presentation");
        // Slats are shared across days; use injected per-(day,time) cells instead.
        $timeGrid.find(".fc-slats tr, .fc-slats td").removeAttr("role");
        // Hide the visual time axis from the accessibility tree; the grid label
        // announces the overall range, and focused slots announce a specific time.
        $timeGrid.find(".fc-slats").attr("aria-hidden", "true");
        this.injectAgendaTimeSlotCells();
      }

      this.applyFullCalendarGridKeyboard();
    }
  },

  agendaGridLabel(view) {
    const viewName = view.name === "agendaDay" ? "Day calendar" : "Week calendar";
    const range = this.visibleTimedSlotRangeLabel();
    if (!range) {
      const structure = this.timedEventsOnly ? "" : " All Day row.";
      return `${viewName}.${structure} Use arrow keys to navigate`;
    }
    const timedSlots = `${this.timeSlotIntervalLabel()} ${range}`;
    const structure = this.timedEventsOnly
      ? `Grid of ${timedSlots}`
      : `All Day row followed by ${timedSlots}`;
    return (
      `${viewName}. ${structure}. ` +
      "Use arrow keys to navigate"
    );
  },

  visibleTimedSlotRangeLabel() {
    const times = this.slotTimes();
    if (!times.length) {
      return null;
    }
    const start = $.fullCalendar.moment(times[0], "HH:mm:ss");
    const end = $.fullCalendar
      .moment(times[times.length - 1], "HH:mm:ss")
      .add(this.slotDurationMinutes(times), "minutes");
    return `from ${this.accessibleTimeLabel(start)} to ${this.accessibleTimeLabel(end)}`;
  },

  timeSlotIntervalLabel() {
    const minutes = this.slotDurationMinutes(this.slotTimes());
    return minutes === 30 ? "half-hour time slots" : `${minutes}-minute time slots`;
  },

  accessibleTimeLabel(time) {
    return time.minutes() === 0 ? time.format("h A") : time.format("h mm A");
  },

  slotDurationMinutes(times) {
    if (times.length < 2) {
      return 30;
    }
    const first = $.fullCalendar.moment(times[0], "HH:mm:ss");
    const second = $.fullCalendar.moment(times[1], "HH:mm:ss");
    const minutes = second.diff(first, "minutes");
    if (minutes <= 0) {
      return 30;
    }
    return minutes;
  },

  injectAgendaTimeSlotCells() {
    const $timeGrid = this.calendar.find(".fc-time-grid").first();
    const $dayCols = $timeGrid.find(".fc-bg .fc-day[data-date]");
    const $contentCols = $timeGrid.find(".fc-content-col");
    const $slats = $timeGrid.find(".fc-slats tr[data-time]");

    if (!$dayCols.length || !$contentCols.length || !$slats.length) {
      return;
    }

    $contentCols.each((colIndex, colEl) => {
      const $col = $(colEl);
      const dateString = $dayCols.eq(colIndex).attr("data-date");
      if (!dateString) {
        return;
      }

      let $container = $col.children(".fc-gather-time-slots");
      if (!$container.length) {
        $container = $('<div class="fc-gather-time-slots"></div>');
        $col.prepend($container);
      } else {
        $container.empty();
      }

      const date = $.fullCalendar.moment(dateString, "YYYY-MM-DD");
      const colTop = $col.offset().top;

      $slats.each((_, slatEl) => {
        const $slat = $(slatEl);
        const timeString = $slat.attr("data-time");
        if (!timeString) {
          return;
        }

        const timeMoment = $.fullCalendar.moment(timeString, "HH:mm:ss");
        const label =
          `${this.gridDateLabel(date, {includeWeekContext: true})}, ` +
          this.accessibleTimeLabel(timeMoment);
        const top = $slat.offset().top - colTop;
        const height = $slat.outerHeight();

        const $slot = $(
          '<div class="fc-gather-time-slot" tabindex="-1" aria-hidden="true"></div>'
        );
        $slot.attr({
          "data-date": dateString,
          "data-time": timeString,
          "aria-label": label,
        });
        $slot.css({
          top: `${top}px`,
          height: `${height}px`,
        });
        $container.append($slot);
      });
    });
  },

  applyFullCalendarGridDateLabels() {
    const view = this.calendar.fullCalendar("getView");
    const isAgenda = view && (view.name === "agendaDay" || view.name === "agendaWeek");

    // Time-grid background columns are layout-only; labeling them creates empty browse targets.
    this.calendar.find(".fc-time-grid .fc-bg .fc-day[data-date]").removeAttr("aria-label");

    const $labelCells = isAgenda
      ? this.calendar.find(".fc-day-grid .fc-bg .fc-day[data-date]:visible")
      : this.calendar.find(".fc-month-view .fc-bg .fc-day[data-date]:visible");

    $labelCells.each((_, cell) => {
      const $cell = $(cell);
      const dateString = $cell.attr("data-date");
      const date = $.fullCalendar.moment(dateString, "YYYY-MM-DD");

      if (date.isValid()) {
        let label = this.gridDateLabel(date, {includeWeekContext: isAgenda});
        if (isAgenda && this.allDayText) {
          label = `${this.allDayText}, ${label}`;
        }
        label += `, ${this.eventCountLabel(this.renderedEventCountOnDay(date))}`;
        $cell.attr("aria-label", label);
      }
    });
  },

  gridDateLabel(date, options) {
    const opts = options || {};
    const today = $.fullCalendar.moment();
    const label = date.format("dddd, MMMM D, YYYY");
    if (date.format("YYYY-MM-DD") === today.format("YYYY-MM-DD")) {
      return `Today, ${label}`;
    }
    if (opts.includeWeekContext && date.isSame(today, "week")) {
      return `This week, ${label}`;
    }
    return label;
  },

  applyFullCalendarGridKeyboard() {
    const view = this.calendar.fullCalendar("getView");
    if (!view) {
      return;
    }

    // Keep grid entry/exit on date/slot cells only so Shift+Tab can leave naturally.
    this.calendar
      .find(".fc-view, .fc-scroller, .fc-agenda-view, .fc-day-grid, .fc-time-grid")
      .removeAttr("tabindex");
    let focusDate = this._fcGridFocusDate;
    let focusTime = this._fcGridFocusTime;

    if (!this.getGridFocusTarget(focusDate, focusTime).length) {
      if (focusDate && this.getGridFocusTarget(focusDate, null).length) {
        focusTime = null;
      } else if (focusDate && this.getGridFocusTarget(focusDate, this.firstSlotTime()).length) {
        focusTime = this.firstSlotTime();
      } else {
        const today = $.fullCalendar.moment().format("YYYY-MM-DD");
        if (this.getGridFocusTarget(today, null).length) {
          focusDate = today;
          focusTime = null;
        } else if (this.getGridFocusTarget(today, this.firstSlotTime()).length) {
          focusDate = today;
          focusTime = this.firstSlotTime();
        } else {
          focusDate = view.intervalStart.format("YYYY-MM-DD");
          focusTime = this.getGridFocusTarget(focusDate, null).length ? null : this.firstSlotTime();
        }
      }
    }

    this.setGridFocus(focusDate, {time: focusTime, focus: this._fcGridShouldFocus});
    this._fcGridShouldFocus = false;
  },

  onGridCellClick(e) {
    const $cell = $(e.currentTarget);
    const date = this.gridDateFromCell($cell);
    if (!date) {
      return;
    }
    this.setGridFocus(date, {time: this.gridTimeFromCell($cell), focus: false});
  },

  onGridCellFocusIn(e) {
    this.finalizePreservedGridCellLabel();
    const $cell = $(e.currentTarget);
    const date = this.gridDateFromCell($cell);
    if (!date) {
      return;
    }
    const dateString = date.format("YYYY-MM-DD");
    const time = this.gridTimeFromCell($cell);
    if (
      $cell.hasClass("fc-gather-grid-active") &&
      this._fcGridFocusDate === dateString &&
      (this._fcGridFocusTime || null) === (time || null)
    ) {
      return;
    }
    this.setGridFocus(date, {time, focus: false});
  },

  onGridCellFocusOut() {
    setTimeout(() => this.finalizePreservedGridCellLabel(), 0);
  },

  onGridCellKeydown(e) {
    const keyCode = e.which || e.keyCode;
    const $cell = $(e.currentTarget);
    const date = this.gridDateFromCell($cell);
    if (!date) {
      return;
    }

    const view = this.calendar.fullCalendar("getView");
    const isAgenda = view && (view.name === "agendaDay" || view.name === "agendaWeek");
    const time = this.gridTimeFromCell($cell);

    if (isAgenda) {
      this.onAgendaGridCellKeydown(e, date, time);
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

  onAgendaGridCellKeydown(e, date, time) {
    const keyCode = e.which || e.keyCode;

    if (keyCode === 13 || keyCode === 32) {
      if (time) {
        this.selectTimeFromGrid(date, time);
      } else {
        this.selectDateFromGrid(date);
      }
      e.preventDefault();
      return;
    }

    let nextDate = date.clone();
    let nextTime = time;

    if (keyCode === 37) {
      nextDate = date.clone().add(-1, "day");
    } else if (keyCode === 39) {
      nextDate = date.clone().add(1, "day");
    } else if (keyCode === 36) {
      nextDate = date.clone().startOf("week");
    } else if (keyCode === 35) {
      nextDate = date.clone().endOf("week").startOf("day");
    } else if (keyCode === 33) {
      nextDate = date.clone().add(-1, "week");
    } else if (keyCode === 34) {
      nextDate = date.clone().add(1, "week");
    } else if (keyCode === 38) {
      if (time) {
        const prevTime = this.adjacentSlotTime(time, -1);
        if (prevTime === undefined) {
          return;
        }
        nextTime = prevTime;
      } else {
        nextDate = date.clone().add(-1, "week");
      }
    } else if (keyCode === 40) {
      if (time) {
        const nextSlot = this.adjacentSlotTime(time, 1);
        if (nextSlot === undefined) {
          return;
        }
        nextTime = nextSlot;
      } else {
        const firstTime = this.firstSlotTime();
        if (!firstTime) {
          nextDate = date.clone().add(1, "week");
        } else {
          nextTime = firstTime;
        }
      }
    } else {
      return;
    }

    this.moveGridFocus(nextDate, nextTime);
    e.preventDefault();
  },

  onGridEventFocusIn(e) {
    const date = this.resolveGridDateFromElement($(e.currentTarget));
    if (!date) {
      return;
    }
    this.setGridFocus(date, {time: null, focus: false});
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

  selectTimeFromGrid(date, timeString) {
    if (!this.canCreate) {
      return;
    }
    const dateString = date.format("YYYY-MM-DD");
    const start = $.fullCalendar.moment(`${dateString}T${timeString}`);
    const end = start.clone().add(this.slotDurationMinutes(this.slotTimes()), "minutes");
    this.calendar.fullCalendar("select", start, end);
  },

  moveGridFocusToDate(date) {
    this.moveGridFocus(date, null);
  },

  moveGridFocus(date, time) {
    const dateString = date.format("YYYY-MM-DD");
    this._fcGridFocusDate = dateString;
    this._fcGridFocusTime = time || null;

    if (this.getGridFocusTarget(dateString, time).length) {
      this.setGridFocus(dateString, {time, focus: true});
      return;
    }

    this._fcGridShouldFocus = true;
    this.prepareFocusedGridCellForRender(date, time);
    this.preserveFocusedGridCellDuringRender();
    this.calendar.fullCalendar("gotoDate", date);
  },

  prepareFocusedGridCellForRender(date, time) {
    const $focused = $(document.activeElement);
    if (time && $focused.hasClass("fc-gather-time-slot")) {
      const timeMoment = $.fullCalendar.moment(time, "HH:mm:ss");
      $focused.attr(
        "aria-label",
        `${this.gridDateLabel(date, {includeWeekContext: true})}, ` +
          this.accessibleTimeLabel(timeMoment)
      );
      return $focused;
    } else if (
      $focused.is(".fc-day[data-date]") &&
      $focused.closest(".fc-agenda-view .fc-day-grid").length
    ) {
      $focused.attr(
        "aria-label",
        `All Day, ${this.gridDateLabel(date, {includeWeekContext: true})}`
      );
      return $focused;
    }
    return $();
  },

  preserveFocusedGridCellDuringRender() {
    const $focused = $(document.activeElement);
    const isTimeSlot = $focused.hasClass("fc-gather-time-slot");
    const isAllDayCell =
      $focused.is(".fc-day[data-date]") &&
      $focused.closest(".fc-agenda-view .fc-day-grid").length > 0;
    if ((!isTimeSlot && !isAllDayCell) || !this.calendar[0].contains($focused[0])) {
      return;
    }

    /*
     * FullCalendar replaces the complete view when keyboard navigation crosses a week
     * boundary. Keep the focused time slot or All Day cell connected to the document
     * during that replacement so VoiceOver does not reset to the start of the page and
     * re-announce every ancestor.
     */
    this._fcPreservedGridCell = $focused;
    this.$el.append($focused);
  },

  restorePreservedGridCell($target) {
    const $preserved = this._fcPreservedGridCell;
    if (!$preserved || !$preserved.length) {
      return $target;
    }

    const preservedIsTimeSlot = $preserved.hasClass("fc-gather-time-slot");
    const targetIsTimeSlot = $target.hasClass("fc-gather-time-slot");
    if (preservedIsTimeSlot !== targetIsTimeSlot) {
      return $target;
    }

    Array.from($preserved[0].attributes).forEach((attribute) => {
      if (!$target[0].hasAttribute(attribute.name)) {
        $preserved.removeAttr(attribute.name);
      }
    });
    Array.from($target[0].attributes).forEach((attribute) => {
      if (attribute.name !== "aria-label") {
        $preserved.attr(attribute.name, attribute.value);
      }
    });
    $preserved.removeAttr("aria-hidden");
    this._fcPreservedGridCellFinalLabel = {
      element: $preserved,
      label: $target.attr("aria-label"),
    };
    this._fcPreservedGridCellLiveAnnouncement = $preserved.attr("aria-label");
    $target.replaceWith($preserved);
    this._fcPreservedGridCell = null;
    return $preserved;
  },

  setGridFocus(date, options) {
    const opts = options || {};
    const dateString = typeof date === "string" ? date : date.format("YYYY-MM-DD");
    const time = Object.prototype.hasOwnProperty.call(opts, "time")
      ? opts.time
      : this._fcGridFocusTime;
    let $target = this.getGridFocusTarget(dateString, time);
    if (!$target.length) {
      return false;
    }
    $target = this.restorePreservedGridCell($target);
    const $cells = this.getNavigableGridCells();

    $cells.attr("tabindex", "-1");
    $cells.removeClass("fc-gather-grid-active");
    $target.attr("tabindex", "0");
    $target.addClass("fc-gather-grid-active");
    if ($target.hasClass("fc-gather-time-slot")) {
      $target.attr({
        role: "button",
      });
      $target.removeAttr("aria-hidden");
    }
    this.updateGridCellAriaStates(dateString, time);
    this._fcGridFocusDate = dateString;
    this._fcGridFocusTime = time || null;
    if (opts.focus && document.activeElement !== $target[0]) {
      $target.focus();
    }
    this.announcePreservedGridCell();

    /*
     * Give screen readers time to process the new focus before removing the prior slot
     * from the accessibility tree. A synchronous removal makes VoiceOver fall back to an
     * unrelated event link elsewhere in the calendar.
     */
    clearTimeout(this._fcGridHideSlotsTimer);
    this._fcGridHideSlotsTimer = setTimeout(() => this.hideInactiveTimeSlots(), 250);

    return true;
  },

  announcePreservedGridCell() {
    const message = this._fcPreservedGridCellLiveAnnouncement;
    this._fcPreservedGridCellLiveAnnouncement = null;
    if (!message || !this.gridFocusLiveRegion.length) {
      return;
    }

    clearTimeout(this._fcGridFocusAnnouncementTimer);
    this.gridFocusLiveRegion.text("");
    this._fcGridFocusAnnouncementTimer = setTimeout(() => {
      this.gridFocusLiveRegion.text(message);
    }, 50);
  },

  finalizePreservedGridCellLabel() {
    const finalLabel = this._fcPreservedGridCellFinalLabel;
    if (!finalLabel || !finalLabel.label || document.activeElement === finalLabel.element[0]) {
      return;
    }

    finalLabel.element.attr("aria-label", finalLabel.label);
    this._fcPreservedGridCellFinalLabel = null;
  },

  hideInactiveTimeSlots() {
    this.calendar
      .find(".fc-gather-time-slot")
      .not(".fc-gather-grid-active")
      .each((_, el) => {
        const $slot = $(el);
        $slot.attr({
          "aria-hidden": "true",
          tabindex: "-1",
        });
        $slot.removeAttr("role");
        $slot.removeAttr("aria-selected");
      });
  },

  updateGridCellAriaStates(selectedDateString, selectedTime) {
    const todayString = $.fullCalendar.moment().format("YYYY-MM-DD");
    const $cells = this.getNavigableGridCells();
    const focusTime = selectedTime || null;

    $cells.each((_, cell) => {
      const $cell = $(cell);
      const dateString = $cell.attr("data-date");
      const cellTime = this.gridTimeFromCell($cell);
      const isSelected =
        dateString === selectedDateString &&
        (cellTime || null) === focusTime;
      const isDayCell = !$cell.hasClass("fc-gather-time-slot");
      const isToday = isDayCell && dateString === todayString;

      if (!isDayCell) {
        $cell.removeAttr("aria-selected");
        $cell.removeAttr("aria-current");
        return;
      }

      // Only expose aria-selected when true; "false" is announced as "not selected".
      if (isSelected) {
        $cell.attr("aria-selected", "true");
      } else {
        $cell.removeAttr("aria-selected");
      }
      if (isToday) {
        $cell.attr("aria-current", "date");
      } else {
        $cell.removeAttr("aria-current");
      }
    });
  },

  getGridDayCell(date) {
    return this.getGridFocusTarget(date, null);
  },

  getGridFocusTarget(date, time) {
    if (!date) {
      return $();
    }
    const dateString = typeof date === "string" ? date : date.format("YYYY-MM-DD");
    if (time) {
      return this.calendar
        .find(`.fc-gather-time-slot[data-date="${dateString}"][data-time="${time}"]`)
        .first();
    }

    return this.getNavigableDayCells()
      .filter((_, el) => $(el).attr("data-date") === dateString)
      .first();
  },

  getNavigableDayCells() {
    const view = this.calendar.fullCalendar("getView");
    if (!view) {
      return this.calendar.find(".fc-day[data-date]");
    }

    if (view.name === "month") {
      return this.calendar.find(".fc-month-view .fc-bg .fc-day[data-date]:visible");
    }

    const $allDayCells = this.calendar.find(
      ".fc-agenda-view .fc-day-grid .fc-bg .fc-day[data-date]:visible"
    );
    if ($allDayCells.length) {
      return $allDayCells;
    }

    return $();
  },

  getNavigableGridCells() {
    const view = this.calendar.fullCalendar("getView");
    if (!view) {
      return this.calendar.find(".fc-day[data-date], .fc-gather-time-slot");
    }

    if (view.name === "month") {
      return this.getNavigableDayCells();
    }

    const $dayCells = this.getNavigableDayCells();
    const $slots = this.calendar.find(".fc-gather-time-slot");
    if ($dayCells.length && $slots.length) {
      return $dayCells.add($slots);
    }
    if ($slots.length) {
      return $slots;
    }
    if ($dayCells.length) {
      return $dayCells;
    }

    return this.calendar.find(".fc-time-grid .fc-bg .fc-day[data-date]:visible");
  },

  gridDateFromCell($cell) {
    const dateString = $cell.attr("data-date") || $cell.data("date");
    if (!dateString) {
      return null;
    }
    return $.fullCalendar.moment(dateString, "YYYY-MM-DD");
  },

  gridTimeFromCell($cell) {
    if (!$cell.hasClass("fc-gather-time-slot")) {
      return null;
    }
    return $cell.attr("data-time") || null;
  },

  slotTimes() {
    return this.calendar
      .find(".fc-slats tr[data-time]")
      .map((_, el) => $(el).attr("data-time"))
      .get();
  },

  firstSlotTime() {
    const times = this.slotTimes();
    return times.length ? times[0] : null;
  },

  /*
   * Returns the adjacent slot time string, null for all-day (when moving up from the first
   * slot and an all-day row exists), or undefined when there is no valid move.
   */
  adjacentSlotTime(time, delta) {
    const times = this.slotTimes();
    const index = times.indexOf(time);
    if (index < 0) {
      return undefined;
    }

    const nextIndex = index + delta;
    if (nextIndex >= 0 && nextIndex < times.length) {
      return times[nextIndex];
    }

    if (nextIndex < 0) {
      if (this.getNavigableDayCells().length) {
        return null;
      }
      return undefined;
    }

    return undefined;
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

  resetRenderedEventCounts() {
    this._renderedEventDateKeys = {};
    this._renderedEventRangesByKey = {};
  },

  eventCountLabel(eventCount) {
    if (eventCount === 0) {
      return "No events";
    } else if (eventCount === 1) {
      return "1 event";
    } else {
      return `${eventCount} events`;
    }
  },

  trackRenderedEventCount(event, el) {
    const $el = $(el);
    if ($el.hasClass("fc-bg-event")) {
      return;
    }

    const eventKey = this.eventCountKey(event);
    const start = event.start.clone();
    const end = this.eventEnd(event);
    const visibleRange = this.visibleDateRange();
    if (!visibleRange) {
      return;
    }

    this._renderedEventRangesByKey[eventKey] = {start, end};

    let date = (start.isAfter(visibleRange.start) ? start : visibleRange.start)
      .clone()
      .startOf("day");
    const lastDate = (end.isBefore(visibleRange.end) ? end : visibleRange.end)
      .clone()
      .subtract(1, "second")
      .startOf("day");
    while (!date.isAfter(lastDate, "day")) {
      const dateString = date.format("YYYY-MM-DD");
      this._renderedEventDateKeys[dateString] = this._renderedEventDateKeys[dateString] || {};
      this._renderedEventDateKeys[dateString][eventKey] = true;
      date.add(1, "day");
    }
  },

  eventCountKey(event) {
    const id = event.id || event.eventId || event._id || event.title;
    return `${id}-${event.start.format()}-${this.eventEnd(event).format()}`;
  },

  visibleDateRange() {
    const view = this.calendar.fullCalendar("getView");
    const start = view && (view.start || view.intervalStart);
    const end = view && (view.end || view.intervalEnd);

    if (!start || !end) {
      return null;
    }

    return {
      start: start.clone(),
      end: end.clone(),
    };
  },

  eventEnd(event) {
    if (event.end) {
      return event.end;
    }

    return event.start.clone().add(1, event.allDay ? "day" : "second");
  },

  renderedEventCountInInterval(start, end) {
    return Object.values(this._renderedEventRangesByKey)
      .filter((range) => range.start.isBefore(end) && range.end.isAfter(start))
      .length;
  },

  renderedEventCountOnDay(date) {
    const dateString = date.format("YYYY-MM-DD");
    return Object.keys(this._renderedEventDateKeys[dateString] || {}).length;
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
    // Explicitly rebuild a11y slots and notify the link manager; minTime changes don't
    // always re-fire eventAfterAllRender since FullCalendar may skip that pipeline.
    this.applyFullCalendarGridA11y();
    setTimeout(() => this.applyFullCalendarGridA11y(), 0);
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

