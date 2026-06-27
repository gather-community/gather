import {Controller} from "@hotwired/stimulus";
import i18n from "../utils/i18n";
import {confirmModal} from "../utils/modal";

export default class extends Controller<HTMLFormElement> {
  static targets = ["allSelected", "item"];

  declare allSelectedTarget: HTMLFormElement;
  declare itemTargets: Array<HTMLFormElement>;

  async actionClicked(event: Event): Promise<void> {
    if (!(event.currentTarget instanceof HTMLElement)) {
      return;
    }

    // The modal is async, so always stop the native submit and re-submit on confirm.
    event.preventDefault();

    const scope = event.currentTarget.dataset.scope;
    const key = event.currentTarget.dataset.key;
    const submitUrl = event.currentTarget.dataset.submitUrl;
    const selectedIds = this.selectedIds();

    if (selectedIds.length === 0) {
      return;
    }

    const confirmation = i18n.t(
      `batchable_tables.confirmations.${scope}.${key}`,
      {count: selectedIds.length}
    );
    if (await confirmModal(confirmation)) {
      if (submitUrl) {
        this.element.action = submitUrl;
      }
      this.element.submit();
    }
  }

  allSelectedClicked(event: Event): void {
    this.selectAllItems(this.allSelectedTarget.checked);
  }

  itemClicked(event: Event): void {
    this.allSelectedTarget.checked = this.allAreSelected();
  }

  allAreSelected(): boolean {
    return this.itemTargets.every((t) => t.checked);
  }

  selectedIds(): Array<string> {
    return this.itemTargets.filter((t) => t.checked).map((t) => t.value);
  }

  selectAllItems(bool: boolean): void {
    this.itemTargets.forEach((t) => t.checked = bool);
  }
}
