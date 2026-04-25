import {Controller} from "@hotwired/stimulus";

// Handles the multi-calendar event form:
// 1. Re-renders the form via AJAX whenever the calendar selection changes.
// 2. Toggles per-slot override time pickers when "Customize times" is checked,
//    pre-populating them once from the main datetime pickers.
export default class extends Controller<HTMLElement> {
  static values = {formUrl: String};

  declare formUrlValue: string;

  // Triggered by calendar select change and cocoon after-remove events.
  calendarChanged(): void {
    this.rerenderForm();
  }

  // Triggered after a cocoon slot is inserted so new select elements get
  // their change listener wired up via Stimulus data-action in the partial.
  slotAdded(): void {
    // Nothing extra needed — Stimulus picks up data-action attrs automatically.
  }

  // Toggles the customize-times time pickers on/off for a single slot.
  // Pre-populates the override pickers from the main datetime pickers the first
  // time the checkbox is checked (does not update them on subsequent changes).
  customizeTimesChanged(event: Event): void {
    const checkbox = event.currentTarget as HTMLInputElement;
    const slotWrapper = checkbox.closest(".nested-fields") as HTMLElement | null;
    if (!slotWrapper) return;

    const fieldsDiv = slotWrapper.querySelector<HTMLElement>(".customize-times-fields");
    if (!fieldsDiv) return;

    if (checkbox.checked) {
      // Pre-populate from main pickers only if the fields are currently empty.
      const mainStartInput = this.element.querySelector<HTMLInputElement>(
        "input[name$='[starts_at]']:not([name*='calendar_slots'])"
      );
      const mainEndInput = this.element.querySelector<HTMLInputElement>(
        "input[name$='[ends_at]']:not([name*='calendar_slots'])"
      );
      const overrideStart = fieldsDiv.querySelector<HTMLInputElement>("input[name*='[starts_at]']");
      const overrideEnd = fieldsDiv.querySelector<HTMLInputElement>("input[name*='[ends_at]']");

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

    const loadingEl = this.element.querySelector<HTMLElement>(
      "[data-calendars--multi-event-form-target='loading']"
    );
    if (loadingEl) loadingEl.classList.remove("hidden");

    try {
      const response = await fetch(this.formUrlValue, {
        method: "POST",
        headers: {"X-CSRF-Token": this.csrfToken()},
        body: new FormData(form),
      });

      if (response.ok) {
        const html = await response.text();
        const tmp = document.createElement("div");
        tmp.innerHTML = html;
        // The partial renders a <div class="row"> wrapper from gather_form_for.
        const newContent = tmp.firstElementChild;
        if (newContent) {
          const formRow = form.closest(".row") as HTMLElement | null;
          const target = formRow ?? form;
          target.outerHTML = newContent.outerHTML;
          this.reinitialize();
        }
      }
    } finally {
      // Loading indicator is gone after re-render; guard in case re-render failed.
      const stillLoading = this.element.querySelector<HTMLElement>(
        "[data-calendars--multi-event-form-target='loading']"
      );
      if (stillLoading) stillLoading.classList.add("hidden");
    }
  }

  private reinitialize(): void {
    // Re-initialize jQuery-based components after DOM replacement.
    if (typeof $ !== "undefined") {
      const $form = $(".calendars--multi-event-form");
      if ((window as any).Gather?.Views?.AjaxSelect2) {
        new (window as any).Gather.Views.AjaxSelect2({el: $form.find(".calendars_event_creator_id")});
      }
      if ((window as any).Gather?.Views?.DirtyChecker) {
        new (window as any).Gather.Views.DirtyChecker({el: $form});
      }
    }
  }

  private csrfToken(): string {
    return (document.querySelector("meta[name=csrf-token]") as HTMLMetaElement)?.content ?? "";
  }
}
