import {Controller} from "@hotwired/stimulus";

export default class extends Controller<HTMLFormElement> {
  static targets = ["overflow", "showButton", "hideButton"];

  declare open: boolean;
  declare overflowTargets: Array<HTMLElement>;
  declare showButtonTarget: HTMLElement;
  declare hideButtonTarget: HTMLElement;

  connect(): void {
    this.open = false;
  }

  toggle(event: Event): void {
    this.open === false ? this.show(event) : this.hide(event);
  }

  show(event: Event): void {
    this.open = true;
    this.showButtonTarget.classList.add("hidden");
    this.hideButtonTarget.classList.remove("hidden");

    // We have to reveal these progressively or Chrome bugs out on the column reflow.
    this.overflowTargets.forEach((el, idx) => setTimeout(() => el.classList.remove("hidden"), idx * 10));
  }

  hide(event: Event): void {
    this.open = false;
    this.showButtonTarget.classList.remove("hidden");
    this.hideButtonTarget.classList.add("hidden");
    this.overflowTargets.forEach((el) => el.classList.add("hidden"));
  }
}
