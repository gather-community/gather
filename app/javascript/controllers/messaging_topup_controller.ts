import {Controller} from "@hotwired/stimulus";
import {jsonFetch} from "../utils/json_fetch";

/*
 * Drives the monthly messaging topup modal on the subscription page. Opens the .gather-modal shell,
 * shows an accurate charge/proration notice as the choice changes (first activation is a full month
 * today with no proration; changing an existing topup fetches the real prorated amount from Stripe),
 * and submits the chosen amount (or a removal) as a Rails form.
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

  save(): void {
    const selected = this.selectedValue();
    if (selected === null || !this.changed(selected)) {
      return;
    }
    const form = document.createElement("form");
    form.method = "post";
    form.action = this.updateUrlValue;
    this.appendHidden(form, "_method", selected === "none" ? "delete" : "patch");
    if (selected !== "none") {
      this.appendHidden(form, "cents", selected);
    }
    const csrfMeta = document.querySelector<HTMLMetaElement>("meta[name=\"csrf-token\"]");
    if (csrfMeta) {
      this.appendHidden(form, "authenticity_token", csrfMeta.content);
    }
    document.body.appendChild(form);
    form.submit();
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
  }

  private hideNotice(): void {
    this.noticeTarget.hidden = true;
  }

  private appendHidden(form: HTMLFormElement, name: string, value: string): void {
    const input = document.createElement("input");
    input.type = "hidden";
    input.name = name;
    input.value = value;
    form.appendChild(input);
  }
}
