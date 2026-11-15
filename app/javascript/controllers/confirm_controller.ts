import {Controller} from "@hotwired/stimulus";
import {confirmModal} from "../utils/modal";

/*
 * Gates a link with the app modal while leaving its `method:` handling to jquery_ujs. On click we
 * pre-empt UJS, show the modal, and on confirm re-fire the click so UJS performs its normal
 * method/form submission. A flag lets the synthetic re-fired click pass straight through.
 */
export default class extends Controller<HTMLElement> {
  static values = {
    message: String,
    title: String,
    confirmLabel: String,
    cancelLabel: String,
    confirmVariant: String,
  };

  declare readonly messageValue: string;
  declare readonly titleValue: string;
  declare readonly confirmLabelValue: string;
  declare readonly cancelLabelValue: string;
  declare readonly confirmVariantValue: string;

  confirmed = false;

  async check(event: Event): Promise<void> {
    if (this.confirmed) {
      this.confirmed = false;
      return; // Synthetic re-fire — let the event bubble to UJS
    }

    event.preventDefault();
    event.stopPropagation(); // Stop UJS's document-delegated handler from acting now

    const ok = await confirmModal(this.messageValue, {
      title: this.titleValue || undefined,
      confirmLabel: this.confirmLabelValue || undefined,
      cancelLabel: this.cancelLabelValue || undefined,
      confirmVariant: (this.confirmVariantValue as "primary" | "default" | "danger") || undefined,
    });
    if (!ok) {
      return;
    }

    this.confirmed = true;
    this.element.click(); // Re-fire — bubbles to UJS, which honors data-method
  }
}
