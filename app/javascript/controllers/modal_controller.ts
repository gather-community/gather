import {Controller} from "@hotwired/stimulus";

export type ButtonVariant = "primary" | "default" | "danger";
export interface ModalButton {
  label: string;
  variant?: ButtonVariant;
}
export interface ModalOptions {
  title: string; // Required — every modal shows a title
  content: string; // Trusted HTML (links allowed) — developer-provided, never raw user input
  buttons: Array<string | ModalButton>;
  input?: { placeholder?: string; value?: string } | false;
}
export interface ModalResult {
  index: number; // -1 for the X button, overlay click, or Esc
  value: string | null; // Text input value, or null when no input is shown
}

/*
 * Owns the single, layout-rendered modal shell. Opened imperatively via utils/modal.ts, which
 * locates this controller and calls open(). One instance exists per page (natural singleton).
 */
export default class extends Controller {
  static targets = ["header", "title", "body", "input", "footer"];

  declare readonly titleTarget: HTMLElement;
  declare readonly bodyTarget: HTMLElement;
  declare readonly inputTarget: HTMLInputElement;
  declare readonly footerTarget: HTMLElement;

  private settle: ((result: ModalResult) => void) | null = null;
  private buttonCount = 0;
  private previouslyFocused: HTMLElement | null = null;

  open(options: ModalOptions): Promise<ModalResult> {
    // If a modal is already open, dismiss it so we never strand a pending promise.
    if (this.settle) {
      this.dismiss();
    }

    this.renderTitle(options.title);
    this.bodyTarget.innerHTML = options.content;
    this.renderInput(options.input);
    this.renderButtons(options.buttons);

    this.previouslyFocused = document.activeElement as HTMLElement | null;
    this.element.classList.remove("hiding");
    document.body.classList.add("gather-modal-open");
    this.focusInitial();

    return new Promise<ModalResult>((resolve) => {
      this.settle = resolve;
    });
  }

  buttonClicked(event: Event): void {
    const index = Number((event.currentTarget as HTMLElement).dataset.index);
    this.resolve({index, value: this.inputValue()});
  }

  dismiss(): void {
    this.resolve({index: -1, value: null});
  }

  // Enter in the text input acts as the final (confirm) button.
  inputSubmit(event: Event): void {
    event.preventDefault();
    if (this.buttonCount > 0) {
      this.resolve({index: this.buttonCount - 1, value: this.inputValue()});
    }
  }

  private renderTitle(title: string): void {
    this.titleTarget.textContent = title;
  }

  private renderInput(input: ModalOptions["input"]): void {
    if (input) {
      this.inputTarget.value = input.value || "";
      this.inputTarget.placeholder = input.placeholder || "";
      this.inputTarget.classList.remove("hiding");
    } else {
      this.inputTarget.value = "";
      this.inputTarget.classList.add("hiding");
    }
  }

  private renderButtons(buttons: Array<string | ModalButton>): void {
    this.footerTarget.innerHTML = "";
    this.buttonCount = buttons.length;
    buttons.forEach((button, index) => {
      const {label, variant = "default"} = typeof button === "string" ? {label: button} : button;
      const el = document.createElement("button");
      el.type = "button";
      el.className = `btn btn-${variant}`;
      el.textContent = label;
      el.dataset.index = String(index);
      el.addEventListener("click", this.buttonClicked.bind(this));
      this.footerTarget.appendChild(el);
    });
  }

  private focusInitial(): void {
    const input = this.inputTarget;
    if (!input.classList.contains("hiding")) {
      input.focus();
      input.select();
    } else {
      this.footerTarget.querySelector<HTMLButtonElement>("button")?.focus();
    }
  }

  private inputValue(): string | null {
    return this.inputTarget.classList.contains("hiding") ? null : this.inputTarget.value;
  }

  private resolve(result: ModalResult): void {
    if (!this.settle) {
      return;
    }
    const settle = this.settle;
    this.settle = null;
    this.element.classList.add("hiding");
    document.body.classList.remove("gather-modal-open");
    this.previouslyFocused?.focus();
    this.previouslyFocused = null;
    settle(result);
  }
}
