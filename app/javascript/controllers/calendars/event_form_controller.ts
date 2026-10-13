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
 * - drops the time from the date pickers while "All-day event" is ticked;
 * - starts the shared Backbone helpers the form uses: the searchable pickers for the creator and
 *   sponsor, and the unsaved-changes check. Those are used across many forms, so they're started
 *   from here rather than converted with this form.
 */
export default class extends Controller<HTMLFormElement> {
  static targets = ["kind", "allDay", "kindNotice"];
  static values = {communityId: Number};

  declare readonly hasKindTarget: boolean;
  declare readonly kindTarget: HTMLSelectElement;
  declare readonly hasAllDayTarget: boolean;
  declare readonly allDayTarget: HTMLInputElement;
  declare readonly kindNoticeTargets: HTMLElement[];
  declare readonly communityIdValue: number;

  private dateFormat: string = null;

  connect() {
    // The date pickers are set up by legacy code when the page is ready, which may come after this.
    $(() => {
      this.dateFormat = $(this.element).find(".datetimepicker input").data("dateOptions").format;
      this.kindChanged();
      this.allDayChanged();

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
}
