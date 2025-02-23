import {Controller} from "@hotwired/stimulus";

/*
 * We should move to i18n-js v4 later, which would let us get rid of this
 * gross global declaration. But to do that, we'd have to figure out how
 * to use npm packages in the legacy Backbone JS stuff since that uses
 * i18n-js too.
 */
declare global {
  var I18n: {t(key:string, params:{}): string};
}

export default class extends Controller<HTMLFormElement> {
  static targets = ["allSelected", "item"];

  declare allSelectedTarget: HTMLFormElement;
  declare itemTargets: Array<HTMLFormElement>;

  actionClicked(event: Event): void {
    if (event.currentTarget instanceof HTMLElement) {
      const scope = event.currentTarget.dataset.scope;
      const key = event.currentTarget.dataset.key;
      const selectedIds = this.selectedIds();

      console.log(selectedIds);

      if (selectedIds.length == 0) {
        event.preventDefault();
        return;
      }

      const confirmation = I18n.t(`batchable_tables.confirmations.${scope}.${key}`, {count: selectedIds.length});
      if (confirm(confirmation)) {
        this.element.action = event.currentTarget.dataset.submitUrl;
      } else {
        event.preventDefault();
      }
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
