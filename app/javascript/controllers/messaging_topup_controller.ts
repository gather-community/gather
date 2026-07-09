import {Controller} from "@hotwired/stimulus";
import {jsonFetch} from "../utils/json_fetch";

/*
 * Drives the monthly messaging topup modal on the subscription page. Opens the .gather-modal shell,
 * shows an accurate charge/proration notice as the choice changes (first activation is a full month
 * today with no proration; changing an existing topup fetches the real prorated amount from Stripe),
 * and submits the chosen amount (or a removal) over AJAX behind the global loader.
 */
export default class extends Controller {
  static targets = ["modal", "notice", "save"];
  static values = {
    previewUrl: String,
    updateUrl: String,
    currentCents: Number,
    hasTopup: Boolean,
  };

  declare readonly modalTarget: HTMLElement;
  declare readonly noticeTarget: HTMLElement;
  declare readonly saveTarget: HTMLButtonElement;
  declare readonly previewUrlValue: string;
  declare readonly updateUrlValue: string;
  declare readonly currentCentsValue: number;
  declare readonly hasTopupValue: boolean;

  open(event: Event): void {
    event.preventDefault();
    this.modalTarget.classList.remove("hiding");
    document.body.classList.add("gather-modal-open");
  }

  close(): void {
    this.modalTarget.classList.add("hiding");
    document.body.classList.remove("gather-modal-open");
  }

  // A radio changed: figure out whether it's a real change and render the matching notice.
  async choose(event: Event): Promise<void> {
    const input = event.target as HTMLInputElement;
    const selected = input.value; // "none" or the amount in cents
    if (!this.changed(selected)) {
      this.saveTarget.disabled = true;
      this.hideNotice();
      return;
    }
    this.saveTarget.disabled = false;

    if (selected === "none") {
      this.showNotice(
        "Your monthly topup will be canceled at the end of the current billing month. "
        + "No further charges, and your existing balance stays."
      );
    } else if (!this.hasTopupValue) {
      const label = input.dataset.messagingTopupLabel;
      this.showNotice(
        `Your payment method on file will be charged ${label} today for a full month, `
        + `then ${label} on this day each month.`
      );
    } else {
      await this.showChangeNotice(selected, input.dataset.messagingTopupLabel || "");
    }
  }

  // Fetches the exact prorated amount for changing an existing topup and renders it.
  private async showChangeNotice(cents: string, label: string): Promise<void> {
    this.showNotice("Calculating…");
    const result = await jsonFetch(this.previewUrlValue, {method: "POST", body: {cents}});
    if (!result || !result.immediate_charge) {
      this.showNotice(`Starting next billing month you'll be charged ${label} per month.`);
      return;
    }
    const when = result.is_credit
      ? `you'll receive a credit of ${result.immediate_charge} toward your next invoice`
      : `your payment method on file will be charged about ${result.immediate_charge} today (prorated)`;
    this.showNotice(`Now ${when}, then ${label} per month from ${result.next_bill_date}.`);
  }

  // Submits the change over AJAX behind the global loader. The server credits the wallet
  // synchronously, so on success we reload to the (green) success flash with the balance already
  // updated. On failure we keep the modal open and show the reason plus an operator reference and
  // the time it was attempted.
  async save(): Promise<void> {
    const selected = this.selectedValue();
    if (selected === null || !this.changed(selected)) {
      return;
    }
    const attemptedAt = new Date().toLocaleString();
    this.saveTarget.disabled = true;
    this.showLoader();
    try {
      const result = selected === "none"
        ? await jsonFetch(this.updateUrlValue, {method: "DELETE"})
        : await jsonFetch(this.updateUrlValue, {method: "PATCH", body: {cents: selected}});
      if (result && result.ok) {
        window.location.reload(); // keep the loader up through the reload
        return;
      }
      this.showError(result, attemptedAt);
    } catch {
      this.showError(null, attemptedAt);
    }
    this.hideLoader();
    this.saveTarget.disabled = false;
  }

  // Whether `selected` differs from the currently-saved topup ("none" when there is none).
  private changed(selected: string): boolean {
    const current = this.hasTopupValue ? String(this.currentCentsValue) : "none";
    return selected !== current;
  }

  private selectedValue(): string | null {
    const checked = this.element.querySelector<HTMLInputElement>("input[name=\"topup_choice\"]:checked");
    return checked ? checked.value : null;
  }

  private showNotice(text: string): void {
    this.noticeTarget.textContent = text;
    this.noticeTarget.hidden = false;
    this.noticeTarget.classList.remove("messaging-topup-notice--error");
  }

  private hideNotice(): void {
    this.noticeTarget.hidden = true;
  }

  // result is the JSON body ({error, reference}) on a handled failure, or null when the request
  // never completed. attemptedAt is the local time the user clicked Save, for operator debugging.
  private showError(result: {[key: string]: any} | null, attemptedAt: string): void {
    const reason = (result && result.error) || "Something went wrong and your topup was not changed.";
    const reference = result && result.reference ? ` Reference: ${result.reference}.` : "";
    this.showNotice(
      `${reason}${reference} (Attempted ${attemptedAt}.) `
      + "If this keeps happening, please contact Gather support with that reference and time."
    );
    this.noticeTarget.classList.add("messaging-topup-notice--error");
  }

  private showLoader(): void {
    document.getElementById("glb-load-ind")?.classList.remove("hiding");
  }

  private hideLoader(): void {
    document.getElementById("glb-load-ind")?.classList.add("hiding");
  }
}
