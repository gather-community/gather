import {Controller} from "@hotwired/stimulus";

interface UserResult {
  id: number;
  name: string;
  email: string | null;
  community: string;
}

const DEBOUNCE_MS = 200;

/*
 * Picks any number of users from any community for a form field. A typeahead queries a JSON
 * endpoint as the user types and shows the matches in a listbox (mouse or arrow keys + Enter).
 * Each chosen user is added to a list as a hidden user_ids[] field, copied from a <template>, so
 * nothing changes until the enclosing form is saved. User-facing messages come in as translated
 * values from the view.
 */
export default class extends Controller<HTMLElement> {
  static targets = ["input", "results", "chosen", "template"];
  static values = {
    url: String,
    minLength: Number,
    tooShort: String,
    searching: String,
    noResults: String,
    error: String,
  };

  declare readonly inputTarget: HTMLInputElement;
  declare readonly resultsTarget: HTMLUListElement;
  declare readonly chosenTarget: HTMLUListElement;
  declare readonly templateTarget: HTMLTemplateElement;
  declare readonly urlValue: string;
  declare readonly minLengthValue: number;
  declare readonly tooShortValue: string;
  declare readonly searchingValue: string;
  declare readonly noResultsValue: string;
  declare readonly errorValue: string;

  results: UserResult[] = [];
  activeIndex = -1;
  timer: number | undefined;
  abortController: AbortController | undefined;

  disconnect(): void {
    window.clearTimeout(this.timer);
    this.abortController?.abort();
  }

  search(): void {
    window.clearTimeout(this.timer);
    const query = this.inputTarget.value.trim();
    if (query.length === 0) {
      this.close();
      return;
    }
    if (query.length < this.minLengthValue) {
      this.showMessage(this.tooShortValue);
      return;
    }
    this.timer = window.setTimeout(() => this.fetchResults(query), DEBOUNCE_MS);
  }

  keydown(event: KeyboardEvent): void {
    switch (event.key) {
    case "ArrowDown":
      event.preventDefault();
      this.moveActive(1);
      break;
    case "ArrowUp":
      event.preventDefault();
      this.moveActive(-1);
      break;
    case "Enter":
      // Never submit an enclosing form with whatever was typed.
      event.preventDefault();
      if (this.activeIndex >= 0) {
        this.choose(this.results[this.activeIndex]);
      }
      break;
    case "Escape":
      this.close();
      break;
    default:
      break;
    }
  }

  close(): void {
    this.resultsTarget.hidden = true;
    this.inputTarget.setAttribute("aria-expanded", "false");
    this.inputTarget.removeAttribute("aria-activedescendant");
    this.activeIndex = -1;
  }

  remove(event: Event): void {
    (event.currentTarget as HTMLElement).closest("li")?.remove();
    this.inputTarget.focus();
  }

  // Clicking a result would otherwise blur the input and close the list before the click lands.
  preventBlur(event: MouseEvent): void {
    event.preventDefault();
  }

  private async fetchResults(query: string): Promise<void> {
    this.abortController?.abort();
    this.abortController = new AbortController();
    this.showMessage(this.searchingValue);
    try {
      const params = new URLSearchParams({q: query, exclude: this.chosenIds().join(",")});
      const url = `${this.urlValue}?${params}`;
      const response = await fetch(url, {
        headers: {Accept: "application/json"},
        signal: this.abortController.signal,
      });
      if (!response.ok) {
        throw new Error(`User search failed with status ${response.status}`);
      }
      const data = await response.json();
      this.renderResults(data.results as UserResult[]);
    } catch (error) {
      if (error instanceof DOMException && error.name === "AbortError") {
        return; // Superseded by a newer search.
      }
      this.showMessage(this.errorValue);
      throw error;
    }
  }

  private renderResults(results: UserResult[]): void {
    this.results = results;
    this.activeIndex = -1;
    if (results.length === 0) {
      this.showMessage(this.noResultsValue);
      return;
    }
    this.resultsTarget.replaceChildren(...results.map((user, index) => this.buildOption(user, index)));
    this.open();
  }

  private buildOption(user: UserResult, index: number): HTMLLIElement {
    const li = document.createElement("li");
    li.id = `user-picker-option-${user.id}`;
    li.className = "user-picker-option";
    li.setAttribute("role", "option");
    li.setAttribute("aria-selected", "false");

    const name = document.createElement("span");
    name.className = "user-picker-name";
    name.textContent = user.name;

    const details = document.createElement("span");
    details.className = "user-picker-details";
    details.textContent = [user.community, user.email].filter(Boolean).join(" · ");

    li.append(name, details);
    li.addEventListener("click", () => this.choose(user));
    li.addEventListener("mousemove", () => this.setActive(index));
    return li;
  }

  private showMessage(message: string): void {
    this.results = [];
    this.activeIndex = -1;
    const li = document.createElement("li");
    li.className = "user-picker-message";
    li.textContent = message;
    this.resultsTarget.replaceChildren(li);
    this.open();
  }

  private open(): void {
    this.resultsTarget.hidden = false;
    this.inputTarget.setAttribute("aria-expanded", "true");
  }

  private moveActive(delta: number): void {
    if (this.results.length === 0) {
      return;
    }
    const count = this.results.length;
    this.setActive((this.activeIndex + delta + count) % count);
  }

  private setActive(index: number): void {
    this.activeIndex = index;
    const options = this.resultsTarget.querySelectorAll<HTMLLIElement>(".user-picker-option");
    options.forEach((option, i) => {
      const active = i === index;
      option.classList.toggle("active", active);
      option.setAttribute("aria-selected", active ? "true" : "false");
      if (active) {
        this.inputTarget.setAttribute("aria-activedescendant", option.id);
        option.scrollIntoView({block: "nearest"});
      }
    });
  }

  private choose(user: UserResult): void {
    const item = this.templateTarget.content.firstElementChild?.cloneNode(true);
    if (!(item instanceof HTMLLIElement)) {
      throw new Error("User picker template must contain an <li>");
    }
    item.dataset.userId = String(user.id);
    item.querySelectorAll<HTMLInputElement>("input[type=hidden]").forEach((input) => {
      input.value = String(user.id);
    });
    this.setText(item, ".user-picker-name", user.name);
    this.setText(item, ".user-picker-details", [user.community, user.email].filter(Boolean).join(" · "));
    this.chosenTarget.append(item);
    this.inputTarget.value = "";
    this.close();
  }

  private setText(item: HTMLElement, selector: string, text: string): void {
    const element = item.querySelector(selector);
    if (element) {
      element.textContent = text;
    }
  }

  private chosenIds(): string[] {
    return Array.from(this.chosenTarget.querySelectorAll<HTMLLIElement>("li[data-user-id]"))
      .map((item) => item.dataset.userId ?? "");
  }
}
