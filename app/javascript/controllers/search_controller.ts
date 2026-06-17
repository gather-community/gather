import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = [
    "gatherResults", "driveResults",
    "gatherSpinner", "driveSpinner",
    "gatherCount", "driveCount",
    "loadMoreDrive",
    "typeFilters",
  ];
  static values = { url: String, query: String, types: String };

  declare gatherResultsTarget: HTMLElement;
  declare driveResultsTarget: HTMLElement;
  declare gatherSpinnerTarget: HTMLElement;
  declare driveSpinnerTarget: HTMLElement;
  declare gatherCountTargets: HTMLElement[];
  declare driveCountTargets: HTMLElement[];
  declare loadMoreDriveTarget: HTMLElement;
  declare typeFiltersTarget: HTMLElement;
  declare hasGatherResultsTarget: boolean;
  declare hasDriveResultsTarget: boolean;
  declare hasGatherSpinnerTarget: boolean;
  declare hasDriveSpinnerTarget: boolean;
  declare hasLoadMoreDriveTarget: boolean;
  declare urlValue: string;
  declare queryValue: string;
  declare typesValue: string;

  connect(): void {
    if (this.queryValue) {
      // Empty typesValue means all types (including drive) are selected
      const allTypes = !this.typesValue;
      const types = allTypes ? [] : this.typesValue.split(" ");
      const showGather = allTypes || types.some(t => t !== "drive");
      const showDrive  = allTypes || types.includes("drive");
      if (showGather) this.fetchSection("gather");
      if (showDrive)  this.fetchSection("drive");
    }
  }

  typeChanged(): void {
    const allBoxes = Array.from(
      this.typeFiltersTarget.querySelectorAll<HTMLInputElement>("input[type=checkbox]")
    );
    const checked = allBoxes.filter(el => el.checked).map(el => el.value);
    const allChecked = checked.length === allBoxes.length;

    // Rebuild URL with new types and navigate (omit types param when all are selected)
    const url = new URL(window.location.href);
    if (checked.length > 0 && !allChecked) {
      url.searchParams.set("types", checked.join("+"));
    } else {
      url.searchParams.delete("types");
    }
    window.location.assign(url.toString());
  }

  async fetchSection(section: "gather" | "drive", pageToken?: string): Promise<void> {
    const url = new URL(this.urlValue, window.location.origin);
    url.searchParams.set("search", this.queryValue);
    url.searchParams.set("source", section);
    // Only set types param when not all types are selected (empty typesValue = all)
    if (this.typesValue) url.searchParams.set("types", this.typesValue.replace(/ /g, "+"));
    if (pageToken) url.searchParams.set("page_token", pageToken);

    const isGather = section === "gather";
    const hasResultsEl = isGather ? this.hasGatherResultsTarget : this.hasDriveResultsTarget;
    if (!hasResultsEl) return;

    const resultsEl = isGather ? this.gatherResultsTarget : this.driveResultsTarget;
    const spinnerEl = isGather
      ? (this.hasGatherSpinnerTarget ? this.gatherSpinnerTarget : null)
      : (this.hasDriveSpinnerTarget ? this.driveSpinnerTarget : null);

    spinnerEl?.classList.remove("hidden");

    let data: { html: string; count: number; next_page_token: string | null };
    try {
      const resp = await fetch(url.toString(), {
        headers: { Accept: "application/json" },
      });
      data = await resp.json();
    } catch {
      resultsEl.innerHTML = '<div class="center-notice">Error loading results. Please try again.</div>';
      spinnerEl?.classList.add("hidden");
      return;
    }

    if (pageToken) {
      resultsEl.insertAdjacentHTML("beforeend", data.html);
    } else {
      resultsEl.innerHTML = data.html;
      const count = data.count ?? 0;
      const countTargets = isGather ? this.gatherCountTargets : this.driveCountTargets;
      countTargets.forEach(el => { el.textContent = count > 0 ? ` (${count})` : ""; });
    }

    spinnerEl?.classList.add("hidden");

    if (!isGather && this.hasLoadMoreDriveTarget) {
      if (data.next_page_token) {
        this.loadMoreDriveTarget.dataset.pageToken = data.next_page_token;
        this.loadMoreDriveTarget.classList.remove("hidden");
      } else {
        this.loadMoreDriveTarget.classList.add("hidden");
      }
    }
  }

  loadMoreDrive(event: Event): void {
    event.preventDefault();
    const token = (event.currentTarget as HTMLElement).dataset.pageToken;
    this.loadMoreDriveTarget.classList.add("hidden");
    this.fetchSection("drive", token);
  }
}
