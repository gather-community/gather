import {Controller} from "@hotwired/stimulus";

/*
 * From the legacy jQuery/Backbone bundle (legacy.js), which loads before this one. Untyped, as that
 * bundle has no type definitions.
 */
/* eslint-disable @typescript-eslint/no-explicit-any */
declare const $: any;
declare const Gather: any;

// The dp.change event from bootstrap-datetimepicker, with moment.js dates (null when empty).
interface PickerChange {
  date: any;
  oldDate: any;
}
/* eslint-enable @typescript-eslint/no-explicit-any */

/*
 * The event form's behavior in the browser:
 * - shows only the pre-notices for the chosen kind (ones that don't name kinds always show);
 * - drops the time from the date pickers while "All-Day Event?" is ticked;
 * - shows only the repeat fields that apply (see _repeat_fields.html.erb), and keeps the unit after the
 *   interval ("weeks") in step with the frequency and number;
 * - moves the end time along with the start time, keeping the event's length;
 * - keeps the start date's weekday ticked and locked among the weekly repeat days, moving it when the
 *   start date changes;
 * - opens an empty repeat end date picker on one month after the start, rather than on today;
 * - sends timesChanged when the start or end changes, which the form-refresh controller answers by
 *   re-rendering what depends on them, such as the monthly repeat choices. The pickers' changes don't
 *   fire the browser change event that other fields' do;
 * - keeps disabled pickers from opening (EventForm#schedule_editable?);
 * - starts the shared Backbone helpers the form uses: the searchable pickers for the creator and
 *   sponsor, and the unsaved-changes check. Those are used across many forms, so they're started
 *   from here rather than converted with this form.
 */
export default class extends Controller<HTMLFormElement> {
  static targets = ["kind", "allDay", "kindNotice", "repeatFrequency", "repeatInterval", "repeatEnds",
    "repeatDetail", "repeatWeekday", "repeatUnit"];
  static values = {communityId: Number};

  declare readonly hasKindTarget: boolean;
  declare readonly kindTarget: HTMLSelectElement;
  declare readonly hasAllDayTarget: boolean;
  declare readonly allDayTarget: HTMLInputElement;
  declare readonly kindNoticeTargets: HTMLElement[];
  declare readonly hasRepeatFrequencyTarget: boolean;
  declare readonly repeatFrequencyTarget: HTMLSelectElement;
  declare readonly repeatIntervalTarget: HTMLInputElement;
  declare readonly repeatEndsTarget: HTMLSelectElement;
  declare readonly repeatDetailTargets: HTMLElement[];
  declare readonly repeatWeekdayTargets: HTMLInputElement[];
  declare readonly repeatUnitTarget: HTMLElement;
  declare readonly communityIdValue: number;

  private dateFormat: string | null = null;
  private startDate: string | null = null;

  connect() {
    // The date pickers are set up by legacy code when the page is ready, which may come after this.
    $(() => {
      this.dateFormat = $(this.element).find(".calendars_event_starts_at .datetimepicker input")
        .data("dateOptions").format;
      this.kindChanged();
      this.allDayChanged();
      this.repeatChanged();
      this.startDate = this.startDateString();
      $(this.element).find(".calendars_event_starts_at .datetimepicker")
        .on("dp.change", (e: PickerChange) => this.startPickerChanged(e));
      $(this.element).find(".calendars_event_ends_at .datetimepicker")
        .on("dp.change", () => this.dispatch("timesChanged"));
      $(this.element).find(".datetimepicker").each((_: number, el: HTMLElement) => {
        if ($(el).find("input").prop("disabled")) {
          $(el).data("DateTimePicker")?.disable();
        }
      });
      const repeatEndsOn = $(this.element).find(".calendars_event_repeat_ends_on .datetimepicker");
      repeatEndsOn.data("DateTimePicker")?.useCurrent(false);
      repeatEndsOn.on("dp.show", () => this.defaultRepeatEndsOn());

      new Gather.Views.AjaxSelect2({
        el: ".calendars_event_sponsor_id",
        extraData: {"community_id": this.communityIdValue},
      });
      new Gather.Views.AjaxSelect2({el: ".calendars_event_creator_id"});
      new Gather.Views.DirtyChecker({el: this.element});
    });
  }

  // Each kind-specific notice lists its kinds in data-kinds as "{Personal}{Official}".
  kindChanged() {
    const kind = this.hasKindTarget ? this.kindTarget.value : null;
    this.kindNoticeTargets.forEach((notice) => {
      const applies = Boolean(kind) && (notice.dataset.kinds || "").includes(`{${kind}}`);
      /*
       * Kind-specific notices start hidden in the stylesheet (events.scss), so showing one needs an
       * inline display, as jQuery's show() used to set.
       */
      notice.style.display = applies ? "block" : "none";
    });
  }

  /*
   * Removes the time part of the start and end pickers' format (everything from " h:") while all-day is
   * ticked. Other pickers, such as the repeat end date's, are dates only and keep their own format.
   */
  allDayChanged() {
    if (this.dateFormat === null) {
      return;
    }
    const allDay = this.hasAllDayTarget && this.allDayTarget.checked;
    const format = allDay ? this.dateFormat.replace(/ h:.*$/i, "") : this.dateFormat;
    $(this.element).find(".calendars_event_starts_at, .calendars_event_ends_at").find(".datetimepicker")
      .each((_: number, el: HTMLElement) => {
        $(el).data("DateTimePicker").format(format);
      });
  }

  private startPickerChanged(event: PickerChange) {
    this.moveEnd(event);
    this.startDateChanged();
    this.dispatch("timesChanged");
  }

  /*
   * Moves the end by as much as the start moved, as calendar apps do, so changing the start doesn't
   * leave an event that ends before it begins. Nothing moves if either time is empty.
   */
  private moveEnd(event: PickerChange) {
    const end = this.picker("ends_at");
    if (!event.date || !event.oldDate || !end?.date()) {
      return;
    }
    end.date(end.date().clone().add(event.date.diff(event.oldDate)));
  }

  // An empty repeat end date opens on one month after the start. A date already chosen is kept.
  private defaultRepeatEndsOn() {
    const endsOn = this.picker("repeat_ends_on");
    const start = this.startMoment();
    if (endsOn && !endsOn.date() && start) {
      endsOn.date(start.clone().add(1, "month"));
    }
  }

  // Only a change of date moves the weekday lock, not a change of time.
  private startDateChanged() {
    const date = this.startDateString();
    if (date === null || date === this.startDate) {
      return;
    }
    this.startDate = date;
    this.lockStartWeekday();
  }

  /*
   * The start's weekday box is ticked and disabled. When the start moves to another day, the old box
   * is freed, and unticked unless the user had ticked it before it was locked; the new one is locked,
   * remembering whether the user had ticked it. The server adds the start's day whatever is sent.
   */
  private lockStartWeekday() {
    const wday = this.startMoment().day();
    this.repeatWeekdayTargets.forEach((box) => {
      const label = box.closest("label") as HTMLLabelElement;
      const isStart = parseInt(box.value, 10) === wday;
      if (box.disabled && !isStart) {
        box.disabled = false;
        box.checked = box.dataset.tickedBeforeLock === "true";
        label.classList.remove("disabled");
        label.title = "";
      } else if (!box.disabled && isStart) {
        box.dataset.tickedBeforeLock = String(box.checked);
        box.checked = true;
        box.disabled = true;
        label.classList.add("disabled");
        label.title = label.closest<HTMLElement>("[data-locked-title]")?.dataset.lockedTitle || "";
      }
    });
  }

  // A moment.js date from the start picker, or null if it's empty.
  private startMoment() {
    return this.picker("starts_at")?.date() ?? null;
  }

  // The bootstrap-datetimepicker for a field, e.g. "starts_at", if the form has one.
  private picker(field: string) {
    return $(this.element).find(`.calendars_event_${field} .datetimepicker`).data("DateTimePicker");
  }

  private startDateString(): string | null {
    return this.startMoment()?.format("YYYY-MM-DD") ?? null;
  }

  /*
   * Each repeat detail field names when it's shown in data-repeat-show: "repeats" whenever the event
   * repeats, "weekly" or "monthly" for that frequency, and "on_date" or "after_count" for that kind of
   * end. EventForm#repeat_detail_applies? makes the same decision for the page as first shown.
   */
  repeatChanged() {
    if (!this.hasRepeatFrequencyTarget) {
      return;
    }
    const frequency = this.repeatFrequencyTarget.value;
    const repeats = Boolean(frequency) && frequency !== "none";
    const ends = this.repeatEndsTarget.value;
    const shown: Record<string, boolean> = {
      repeats,
      weekly: frequency === "weekly",
      monthly: frequency === "monthly",
      "on_date": repeats && ends === "on_date",
      "after_count": repeats && ends === "after_count",
    };
    this.repeatDetailTargets.forEach((field) => {
      field.style.display = shown[field.dataset.repeatShow || ""] ? "" : "none";
    });

    // The units are translated on the server: {"weekly": {"one": "week", "other": "weeks"}, ...}.
    const units = JSON.parse(this.repeatIntervalTarget.dataset.units || "{}");
    if (repeats && units[frequency]) {
      const count = parseInt(this.repeatIntervalTarget.value, 10);
      this.repeatUnitTarget.textContent = count === 1 ? units[frequency].one : units[frequency].other;
    }
  }
}
