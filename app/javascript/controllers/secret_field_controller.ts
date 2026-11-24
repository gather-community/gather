import {Controller} from "@hotwired/stimulus";

// A read-only field holding a secret: masked by default, with buttons to show/hide it and to copy it.
export default class extends Controller<HTMLElement> {
  static targets = ["input", "toggle", "toggleLabel", "copyLabel"];
  static values = {showLabel: String, hideLabel: String, copiedLabel: String};

  declare readonly inputTarget: HTMLInputElement;
  declare readonly toggleTarget: HTMLButtonElement;
  declare readonly toggleLabelTarget: HTMLElement;
  declare readonly copyLabelTarget: HTMLElement;
  declare readonly showLabelValue: string;
  declare readonly hideLabelValue: string;
  declare readonly copiedLabelValue: string;

  copyResetTimer?: number;

  toggle(): void {
    const reveal = this.inputTarget.type === "password";
    this.inputTarget.type = reveal ? "text" : "password";
    this.toggleLabelTarget.textContent = reveal ? this.hideLabelValue : this.showLabelValue;
    this.toggleTarget.setAttribute("aria-pressed", String(reveal));
    const icon = this.toggleTarget.querySelector(".fa-eye, .fa-eye-slash");
    icon?.classList.toggle("fa-eye", !reveal);
    icon?.classList.toggle("fa-eye-slash", reveal);
  }

  async copy(): Promise<void> {
    await navigator.clipboard.writeText(this.inputTarget.value);
    const label = this.copyLabelTarget;
    const original = label.dataset.originalText ?? label.textContent ?? "";
    label.dataset.originalText = original;
    label.textContent = this.copiedLabelValue;
    window.clearTimeout(this.copyResetTimer);
    this.copyResetTimer = window.setTimeout(() => {
      label.textContent = original;
    }, 2000);
  }

  disconnect(): void {
    window.clearTimeout(this.copyResetTimer);
  }
}
