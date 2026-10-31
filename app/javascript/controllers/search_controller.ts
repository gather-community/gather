import { Controller } from "@hotwired/stimulus";
import i18n from "../utils/i18n";

declare const Gather: any;

interface SectionResponse {
  html: string;
  count: number;
  capped?: boolean;
  next_offset?: number | null;
}

export default class extends Controller {
  static targets = [
    "gatherResults", "driveResults",
    "gatherSpinner", "driveSpinner",
    "gatherCount", "driveCount",
    "gatherList", "driveList", "loadMoreGather", "loadMoreDrive",
    "typeFilters",
  ];
  static values = { url: String, query: String, types: String };

  declare gatherResultsTarget: HTMLElement;
  declare driveResultsTarget: HTMLElement;
  declare gatherSpinnerTarget: HTMLElement;
  declare driveSpinnerTarget: HTMLElement;
  declare gatherCountTargets: HTMLElement[];
  declare driveCountTargets: HTMLElement[];
  declare gatherListTarget: HTMLElement;
  declare driveListTarget: HTMLElement;
  declare loadMoreGatherTarget: HTMLElement;
  declare loadMoreDriveTarget: HTMLElement;
  declare typeFiltersTarget: HTMLElement;
  declare hasGatherResultsTarget: boolean;
  declare hasDriveResultsTarget: boolean;
  declare hasGatherSpinnerTarget: boolean;
  declare hasDriveSpinnerTarget: boolean;
  declare hasGatherListTarget: boolean;
  declare hasDriveListTarget: boolean;
  declare hasLoadMoreGatherTarget: boolean;
  declare hasLoadMoreDriveTarget: boolean;
  declare urlValue: string;
  declare queryValue: string;
  declare typesValue: string;

  connect(): void {
    if (!this.queryValue) return;
    if (this.hasGatherResultsTarget) this.fetchSection("gather");
    if (this.hasDriveResultsTarget) this.fetchSection("drive");
  }

  // Reruns the search with the checked types. Boxes only change when the user clicks them or the
  // select all button.
  typeChanged(): void {
    const boxes = this.typeBoxes();
    const checked = boxes.filter(el => el.checked).map(el => el.value);
    const url = new URL(window.location.href);
    if (checked.length === boxes.length) {
      // No types param means all types.
      url.searchParams.delete("types");
    } else {
      // Space-separated; an empty value means none are checked.
      url.searchParams.set("types", checked.join(" "));
    }
    window.location.assign(url.toString());
  }

  toggleAll(): void {
    const boxes = this.typeBoxes();
    const check = !boxes.every(el => el.checked);
    boxes.forEach(el => { el.checked = check; });
    this.typeChanged();
  }

  loadMoreGather(event: Event): void {
    this.loadMore(event, "gather");
  }

  loadMoreDrive(event: Event): void {
    this.loadMore(event, "drive");
  }

  private loadMore(event: Event, section: "gather" | "drive"): void {
    event.preventDefault();
    const offset = Number((event.currentTarget as HTMLElement).dataset.offset);
    const loadMoreEl = section === "gather" ? this.loadMoreGatherTarget : this.loadMoreDriveTarget;
    loadMoreEl.classList.add("hidden");
    this.fetchSection(section, offset);
  }

  private typeBoxes(): HTMLInputElement[] {
    return Array.from(this.typeFiltersTarget.querySelectorAll<HTMLInputElement>("input[type=checkbox]"));
  }

  private async fetchSection(section: "gather" | "drive", offset = 0): Promise<void> {
    const isGather = section === "gather";
    const url = new URL(this.urlValue, window.location.origin);
    url.searchParams.set("search", this.queryValue);
    url.searchParams.set("source", section);
    // Only set when not all types are selected (empty typesValue = all).
    if (this.typesValue) url.searchParams.set("types", this.typesValue);
    if (offset) url.searchParams.set("offset", String(offset));

    const resultsEl = isGather ? this.gatherResultsTarget : this.driveResultsTarget;
    const spinnerEl = isGather
      ? (this.hasGatherSpinnerTarget ? this.gatherSpinnerTarget : null)
      : (this.hasDriveSpinnerTarget ? this.driveSpinnerTarget : null);
    const appending = offset > 0;

    spinnerEl?.classList.remove("hidden");
    // Later pages load below the fold, away from the section spinner, so use the global indicator.
    if (appending) Gather.loadingIndicator.show();

    let data: SectionResponse;
    try {
      const resp = await fetch(url.toString(), { headers: { Accept: "application/json" } });
      data = await resp.json();
    } catch {
      const notice = document.createElement("div");
      notice.className = "center-notice";
      notice.textContent = i18n.t("search.load_error");
      resultsEl.replaceChildren(notice);
      spinnerEl?.classList.add("hidden");
      if (appending) Gather.loadingIndicator.hide();
      return;
    }

    const hasList = isGather ? this.hasGatherListTarget : this.hasDriveListTarget;
    if (appending && hasList) {
      const listEl = isGather ? this.gatherListTarget : this.driveListTarget;
      listEl.insertAdjacentHTML("beforeend", data.html);
    } else {
      resultsEl.innerHTML = data.html;
      const count = data.count ?? 0;
      const label = data.capped ? i18n.t("search.count_capped", { count }) : String(count);
      const countTargets = isGather ? this.gatherCountTargets : this.driveCountTargets;
      countTargets.forEach(el => { el.textContent = count > 0 ? ` (${label})` : ""; });
    }

    spinnerEl?.classList.add("hidden");
    if (appending) Gather.loadingIndicator.hide();

    const hasLoadMore = isGather ? this.hasLoadMoreGatherTarget : this.hasLoadMoreDriveTarget;
    if (hasLoadMore) {
      this.toggleLoadMore(isGather ? this.loadMoreGatherTarget : this.loadMoreDriveTarget, data.next_offset);
    }
  }

  // Shows the "more" link with the next page's offset on its anchor, or hides it on the last page.
  private toggleLoadMore(el: HTMLElement, nextOffset: number | null | undefined): void {
    const link = el.querySelector("a");
    if (nextOffset !== null && nextOffset !== undefined && link) {
      link.dataset.offset = String(nextOffset);
      el.classList.remove("hidden");
    } else {
      el.classList.add("hidden");
    }
  }
}
