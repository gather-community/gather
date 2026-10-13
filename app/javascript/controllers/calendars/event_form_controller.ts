import {Controller} from "@hotwired/stimulus";

/*
 * From the legacy jQuery/Backbone bundle (legacy.js), which loads before this one. Untyped, as that
 * bundle has no type definitions.
 */
/* eslint-disable @typescript-eslint/no-explicit-any */
declare const $: any;
declare const Gather: any;
/* eslint-enable @typescript-eslint/no-explicit-any */

/*
 * The event form's behavior in the browser:
 * - shows only the pre-notices for the chosen kind (ones that don't name kinds always show);
 * - drops the time from the date pickers while "All-Day Event?" is ticked;
 * - shows only the repeat fields that apply (see _repeat_fields.html.erb), and keeps the unit after the
 *   interval ("weeks") in step with the frequency and number;
 * - keeps the start date's weekday ticked and locked among the weekly repeat days, moving it when the
 *   start date changes;
 * - sends startChanged when the start date changes, which the form-refresh controller answers by
 *   re-rendering what depends on it, such as the monthly repeat choices;
 * - starts the shared Backbone helpers the form uses: the searchable pickers for the creator and
 *   sponsor, and the unsaved-changes check. Those are used across many forms, so they're started
 *   from here rather than converted with this form.
 */
export default class extends Controller<HTMLFormElement> {
  static targets = ["kind", "allDay", "kindNotice", "repeatFrequency", "repeatInterval", "repeatEnds",
    "repeatDetail", "repeatWeekday"];
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
  declare readonly communityIdValue: number;

  private dateFormat: string | null = null;
  private startDate: string | null = null;

  connect() {
    // The date pickers are set up by legacy code when the page is ready, which may come after this.
    $(() => {
      this.dateFormat = $(this.element).find(".datetimepicker input").data("dateOptions").format;
      this.kindChanged();
      this.allDayChanged();
      this.repeatChanged();
      this.startDate = this.startDateString();
      $(this.element).find(".calendars_event_starts_at .datetimepicker")
        .on("dp.change", () => this.startChanged());

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

  // Removes the time part of the date pickers' format (everything from " h:") while all-day is ticked.
  allDayChanged() {
    if (this.dateFormat === null) {
      return;
    }
    const allDay = this.hasAllDayTarget && this.allDayTarget.checked;
    const format = allDay ? this.dateFormat.replace(/ h:.*$/i, "") : this.dateFormat;
    $(this.element).find(".datetimepicker").each((_: number, el: HTMLElement) => {
      $(el).data("DateTimePicker").format(format);
    });
  }

  // Only a change of date matters, not of time, so the time pickers' own changes are ignored.
  startChanged() {
    const date = this.startDateString();
    if (date === null || date === this.startDate) {
      return;
    }
    this.startDate = date;
    this.lockStartWeekday();
    this.dispatch("startChanged");
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
    const picker = $(this.element).find(".calendars_event_starts_at .datetimepicker").data("DateTimePicker");
    return picker ? picker.date() : null;
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
    const hint = this.repeatIntervalTarget.closest(".form-group")?.querySelector(".hint");
    if (repeats && units[frequency] && hint) {
      const count = parseInt(this.repeatIntervalTarget.value, 10);
      hint.textContent = count === 1 ? units[frequency].one : units[frequency].other;
    }
  }
}
