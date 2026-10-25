import {Controller} from "@hotwired/stimulus";
import i18n from "../utils/i18n";
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
      this.showNotice(i18n.t("subscription.topup_notices.cancel"));
    } else if (!this.hasTopupValue) {
      const label = input.dataset.messagingTopupLabel;
      this.showNotice(i18n.t("subscription.topup_notices.first_charge", {amount: label}));
    } else {
      await this.showChangeNotice(selected, input.dataset.messagingTopupLabel || "");
    }
  }

  // Fetches the exact prorated amount for changing an existing topup and renders it.
  private async showChangeNotice(cents: string, label: string): Promise<void> {
    this.showNotice(i18n.t("subscription.topup_notices.calculating"));
    const result = await jsonFetch(this.previewUrlValue, {method: "POST", body: {cents}});
    if (!result || !result.immediate_charge) {
      this.showNotice(i18n.t("subscription.topup_notices.next_month", {amount: label}));
      return;
    }
    const params = {amount: label, date: result.next_bill_date};
    this.showNotice(result.is_credit
      ? i18n.t("subscription.topup_notices.prorated_credit", {...params, credit: result.immediate_charge})
      : i18n.t("subscription.topup_notices.prorated_charge", {...params, charge: result.immediate_charge}));
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
    const attemptedAt = new Date().toLocaleString(i18n.locale);
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

  /*
   * Whether `selected` differs from the effectively-chosen amount ("none" when there is none, which
   * includes a topup that is winding down — see MessagingTopupDecorator#selected_cents). Kept
   * separate from hasTopup, which says only whether a Stripe subscription exists to reprice: during
   * a wind-down the chosen amount is "none" but a change still prorates rather than billing a full
   * month, so the two must not be conflated.
   */
  private changed(selected: string): boolean {
    const current = this.currentCentsValue > 0 ? String(this.currentCentsValue) : "none";
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
    const reason = (result && result.error) || i18n.t("subscription.topup_notices.error_default");
    this.showNotice(result && result.reference
      ? i18n.t("subscription.topup_notices.error_with_reference", {
        reason, reference: result.reference, time: attemptedAt,
      })
      : i18n.t("subscription.topup_notices.error", {reason, time: attemptedAt}));
    this.noticeTarget.classList.add("messaging-topup-notice--error");
  }

  private showLoader(): void {
    document.getElementById("glb-load-ind")?.classList.remove("hiding");
  }

  private hideLoader(): void {
    document.getElementById("glb-load-ind")?.classList.add("hiding");
  }
}
