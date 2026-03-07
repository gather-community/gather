import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = [
    "wikiResults", "driveResults",
    "wikiSpinner", "driveSpinner",
    "loadMoreDrive",
  ];
  static values = { url: String, query: String, source: String };

  declare wikiResultsTarget: HTMLElement;
  declare driveResultsTarget: HTMLElement;
  declare wikiSpinnerTarget: HTMLElement;
  declare driveSpinnerTarget: HTMLElement;
  declare loadMoreDriveTarget: HTMLElement;
  declare hasWikiSpinnerTarget: boolean;
  declare hasDriveSpinnerTarget: boolean;
  declare hasLoadMoreDriveTarget: boolean;
  declare urlValue: string;
  declare queryValue: string;
  declare sourceValue: string;

  connect(): void {
    if (this.queryValue) {
      const source = this.sourceValue || "all";
      if (source === "all" || source === "wiki") this.fetchSection("wiki");
      if (source === "all" || source === "drive") this.fetchSection("drive");
    }
  }

  async fetchSection(section: "wiki" | "drive", pageToken?: string): Promise<void> {
    const url = new URL(this.urlValue, window.location.origin);
    url.searchParams.set("search", this.queryValue);
    url.searchParams.set("source", section);
    if (pageToken) url.searchParams.set("page_token", pageToken);

    const isWiki = section === "wiki";
    const resultsEl = isWiki ? this.wikiResultsTarget : this.driveResultsTarget;
    const spinnerEl = isWiki
      ? (this.hasWikiSpinnerTarget ? this.wikiSpinnerTarget : null)
      : (this.hasDriveSpinnerTarget ? this.driveSpinnerTarget : null);

    spinnerEl?.classList.remove("hidden");

    let data: { html: string; next_page_token: string | null };
    try {
      const resp = await fetch(url.toString(), {
        headers: { Accept: "application/json" },
      });
      data = await resp.json();
    } catch {
      resultsEl.innerHTML = '<p class="text-danger">Error loading results. Please try again.</p>';
      spinnerEl?.classList.add("hidden");
      return;
    }

    if (pageToken) {
      resultsEl.insertAdjacentHTML("beforeend", data.html);
    } else {
      resultsEl.innerHTML = data.html;
    }

    spinnerEl?.classList.add("hidden");

    if (!isWiki && this.hasLoadMoreDriveTarget) {
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
