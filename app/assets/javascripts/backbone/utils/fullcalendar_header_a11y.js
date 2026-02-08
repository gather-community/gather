// FullCalendar header accessibility helpers.
//
// Enhancements:
// - Adds role="toolbar" + aria-label to the calendar header container.
// - Adds aria-label to prev/next/today controls.
// - Adds aria-pressed on active view buttons (agendaDay/agendaWeek/month).
// - Provides focus restoration by mapping a previously-activated control to the new DOM.
//
// This file is included via `legacy.js` (`//= require_tree .`).

window.Gather = window.Gather || {};
Gather.Utils = Gather.Utils || {};

Gather.Utils.FullCalendarHeaderA11y = (function() {
  const VIEW_TYPES = ["agendaDay", "agendaWeek", "month"];

  function headerContainer($calendarEl) {
    // FullCalendar v2+: .fc-toolbar. v1: .fc-header.
    const $toolbar = $calendarEl.find(".fc-toolbar").first();
    if ($toolbar.length) return $toolbar;
    return $calendarEl.find(".fc-header").first();
  }

  function focusKeyFromElement(el) {
    if (!el) return null;
    const className = (el.className || "").toString();

    if (/(\bfc-prev-button\b|\bfc-button-prev\b)/.test(className)) return "prev";
    if (/(\bfc-next-button\b|\bfc-button-next\b)/.test(className)) return "next";
    if (/(\bfc-today-button\b|\bfc-button-today\b)/.test(className)) return "today";

    for (let i = 0; i < VIEW_TYPES.length; i++) {
      const view = VIEW_TYPES[i];
      const re = new RegExp(`(\\bfc-${view}-button\\b|\\bfc-button-${view}\\b)`);
      if (re.test(className)) return view;
    }

    return null;
  }

  function setIfMissingOrDifferent($el, attrs) {
    if (!$el || !$el.length) return;
    Object.keys(attrs).forEach(key => {
      const nextVal = attrs[key];
      if ($el.attr(key) !== nextVal) $el.attr(key, nextVal);
    });
  }

  function isActiveViewButton($btn) {
    // FullCalendar uses `fc-state-active` on active view buttons.
    return $btn.hasClass("fc-state-active") || $btn.hasClass("fc-state-down");
  }

  function enhance($calendarEl, options) {
    const opts = options || {};
    const $header = headerContainer($calendarEl);
    if (!$header.length) return { didRestoreFocus: false };

    setIfMissingOrDifferent($header, {
      role: "toolbar",
      "aria-label": opts.toolbarLabel || "Calendar toolbar"
    });

    // Prev/Next/Today labels (set even if text exists for SR consistency).
    setIfMissingOrDifferent($header.find(".fc-prev-button, .fc-button-prev").first(), {
      "aria-label": "Previous"
    });
    setIfMissingOrDifferent($header.find(".fc-next-button, .fc-button-next").first(), {
      "aria-label": "Next"
    });
    setIfMissingOrDifferent($header.find(".fc-today-button, .fc-button-today").first(), {
      "aria-label": "Today"
    });

    // View buttons + aria-pressed.
    VIEW_TYPES.forEach(view => {
      const $btn = $header.find(`.fc-${view}-button, .fc-button-${view}`).first();
      if (!$btn.length) return;

      const label =
        view === "agendaDay" ? "Day view" :
        view === "agendaWeek" ? "Week view" :
        "Month view";

      setIfMissingOrDifferent($btn, {
        "aria-label": label,
        "aria-pressed": isActiveViewButton($btn) ? "true" : "false"
      });
    });

    let didRestoreFocus = false;
    if (opts.focusKeyToRestore) {
      const key = opts.focusKeyToRestore;
      let selector = null;

      if (key === "prev") selector = ".fc-prev-button, .fc-button-prev";
      if (key === "next") selector = ".fc-next-button, .fc-button-next";
      if (key === "today") selector = ".fc-today-button, .fc-button-today";
      if (VIEW_TYPES.indexOf(key) !== -1) selector = `.fc-${key}-button, .fc-button-${key}`;

      if (selector) {
        const $target = $header.find(selector).filter(":visible").first();
        if (
          $target.length &&
          !$target.prop("disabled") &&
          !$target.hasClass("fc-state-disabled")
        ) {
          $target.focus();
          didRestoreFocus = true;
        }
      }
    }

    return { didRestoreFocus };
  }

  return {
    enhance,
    focusKeyFromElement
  };
})();


