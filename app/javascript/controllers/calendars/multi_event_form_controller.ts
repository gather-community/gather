import { Controller } from "@hotwired/stimulus";
import { morphChildren } from "@hotwired/turbo";

/*
 * Manages the multi-calendar event form:
 * 1. Adds/removes calendar slot rows without Cocoon.
 * 2. Re-renders the form via AJAX (then morphs the DOM) on calendar change,
 *    slot remove, and on first blur of each input. The blurred input names
 *    are sent as _touched[] so the server can filter validation errors to
 *    only the fields the user has interacted with.
 * 3. Toggles per-slot override time pickers when "Customize times" is checked.
 */
export default class extends Controller<HTMLElement> {
  static values = { formUrl: String, nextIndex: Number };
  static targets = ["slotContainer", "slotTemplate"];

  declare formUrlValue: string;
  declare nextIndexValue: number;
  declare slotContainerTarget: HTMLElement;
  declare slotTemplateTarget: HTMLTemplateElement;

  /*
   * Names of inputs the user has interacted with at least once. The server
   * uses this list to filter validation errors so untouched fields don't
   * surface premature errors during data entry.
   */
  private touched = new Set<string>();
  private rerenderTimer: number | null = null;

  private handleBlur = (event: FocusEvent): void => {
    const target = event.target as HTMLElement | null;
    if (
      !(target instanceof HTMLInputElement) &&
      !(target instanceof HTMLSelectElement) &&
      !(target instanceof HTMLTextAreaElement)
    )
      return;
    if (!target.name) return;
    if (this.touched.has(target.name)) return;
    this.touched.add(target.name);
    this.scheduleRerender();
  };

  connect(): void {
    this.element.addEventListener("focusout", this.handleBlur);
  }

  disconnect(): void {
    this.element.removeEventListener("focusout", this.handleBlur);
    if (this.rerenderTimer !== null) {
      window.clearTimeout(this.rerenderTimer);
      this.rerenderTimer = null;
    }
  }

  /*
   * Defers the rerender so it fires after any synchronous click handlers
   * that may follow a blur event (e.g. clicking "Add Calendar" blurs the
   * previously focused field BEFORE addSlot() runs). Also coalesces rapid
   * blur/change events into a single network request, and postpones the
   * rerender while a datetime picker is open (the morph would otherwise
   * invalidate the picker's DOM mid-interaction).
   */
  private scheduleRerender(): void {
    if (this.rerenderTimer !== null) window.clearTimeout(this.rerenderTimer);
    this.rerenderTimer = window.setTimeout(() => {
      this.rerenderTimer = null;
      if (document.querySelector(".bootstrap-datetimepicker-widget")) {
        this.scheduleRerender();
        return;
      }
      this.rerenderForm();
    }, 100);
  }

  private get globalLoadingIndicator(): HTMLElement | null {
    return document.getElementById("glb-load-ind");
  }

  // "Add Calendar" button clicked — clone the template, stamp a unique index.
  addSlot(): void {
    const index = this.nextIndexValue;
    this.nextIndexValue = index + 1;

    const html = this.slotTemplateTarget.innerHTML.replace(
      /__INDEX__/g,
      index.toString(),
    );
    const wrapper = document.createElement("div");
    wrapper.innerHTML = html;
    const node = wrapper.firstElementChild;
    if (node) {
      this.slotContainerTarget.appendChild(node);
    }
  }

  // "Remove" button inside a slot clicked.
  removeSlot(event: Event): void {
    event.preventDefault();
    const btn = event.currentTarget as HTMLElement;
    const slot = btn.closest(".nested-fields") as HTMLElement | null;
    if (!slot) return;

    const destroyInput = slot.querySelector<HTMLInputElement>(
      "input[name*='[_destroy]']",
    );
    if (destroyInput) {
      destroyInput.value = "1";
    }
    slot.classList.add("hidden");
    this.rerenderForm();
  }

  // Triggered by calendar select change.
  calendarChanged(): void {
    this.rerenderForm();
  }

  /*
   * Toggles the customize-times time pickers on/off for a single slot.
   * Pre-populates the override pickers from the main datetime pickers the
   * first time the checkbox is checked.
   */
  customizeTimesChanged(event: Event): void {
    const checkbox = event.currentTarget as HTMLInputElement;
    const slotWrapper = checkbox.closest(
      ".calendar-slot-fields",
    ) as HTMLElement | null;
    if (!slotWrapper) return;

    const fieldsDiv = slotWrapper.querySelector<HTMLElement>(
      ".customize-times-fields",
    );
    if (!fieldsDiv) return;

    if (checkbox.checked) {
      const mainStartInput = this.element.querySelector<HTMLInputElement>(
        "input[name$='[starts_at]']:not([name*='calendar_slots'])",
      );
      const mainEndInput = this.element.querySelector<HTMLInputElement>(
        "input[name$='[ends_at]']:not([name*='calendar_slots'])",
      );
      const overrideStart = fieldsDiv.querySelector<HTMLInputElement>(
        "input[name*='[starts_at]']",
      );
      const overrideEnd = fieldsDiv.querySelector<HTMLInputElement>(
        "input[name*='[ends_at]']",
      );

      if (overrideStart && !overrideStart.value && mainStartInput) {
        overrideStart.value = mainStartInput.value;
      }
      if (overrideEnd && !overrideEnd.value && mainEndInput) {
        overrideEnd.value = mainEndInput.value;
      }
      fieldsDiv.classList.remove("hidden");
    } else {
      fieldsDiv.classList.add("hidden");
    }
  }

  private async rerenderForm(): Promise<void> {
    const form = this.element.closest("form") as HTMLFormElement | null;
    if (!form) return;

    this.globalLoadingIndicator?.classList.remove("hiding");

    try {
      const formData = new FormData(form);
      // Strip Rails' method-override field so Rack doesn't rewrite our POST
      // to PATCH (which would route to update with id="form" on edit pages).
      formData.delete("_method");
      this.touched.forEach((name) => formData.append("_touched[]", name));
      const response = await fetch(this.formUrlValue, {
        method: "POST",
        headers: { "X-CSRF-Token": this.csrfToken() },
        body: formData,
      });

      if (response.ok) {
        const html = await response.text();
        const tmp = document.createElement("div");
        tmp.innerHTML = html;
        const newForm = tmp.querySelector("form") as HTMLElement | null;
        if (newForm) {
          morphChildren(form, newForm);
          this.reinitialize();
        }
      }
    } finally {
      this.globalLoadingIndicator?.classList.add("hiding");
    }
  }

  private reinitialize(): void {
    if (typeof $ !== "undefined") {
      const $form = $(".calendars--multi-event-form");

      // Initialize jQuery datetimepicker on newly rendered elements only.
      // Re-initializing an existing widget destroys and recreates its DOM,
      // which makes open pickers stale mid-interaction.
      const $fn = ($.fn as any);
      if ($fn.datetimepicker) {
        const defaultKeyBinds = $fn.datetimepicker.defaults.keyBinds;
        delete defaultKeyBinds.t;
        $form.find(".datetimepicker").each(function () {
          const $el = $(this);
          if ($el.data("DateTimePicker")) return;
          $el.datetimepicker({
            icons: {
              date: "fa fa-calendar",
              time: "fa fa-clock",
              up: "fa fa-chevron-up",
              down: "fa fa-chevron-down",
              previous: "fa fa-chevron-left",
              next: "fa fa-chevron-right",
              today: "fa fa-crosshairs",
              clear: "fa fa-trash",
              close: "fa fa-times",
            },
            keyBinds: defaultKeyBinds,
          });
        });
      }

      if ((window as any).Gather?.Views?.AjaxSelect2) {
        new (window as any).Gather.Views.AjaxSelect2({
          el: $form.find(".calendars_event_creator_id"),
        });
      }
      if ((window as any).Gather?.Views?.DirtyChecker) {
        new (window as any).Gather.Views.DirtyChecker({ el: $form });
      }
    }
  }

  private csrfToken(): string {
    return (
      (document.querySelector("meta[name=csrf-token]") as HTMLMetaElement)
        ?.content ?? ""
    );
  }
}
