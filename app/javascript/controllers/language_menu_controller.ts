import {Controller} from "@hotwired/stimulus";

const ONE_YEAR_IN_SECONDS = 60 * 60 * 24 * 365;

/*
 * The language menu in the page footer. It starts as a "Change Language" link that reveals the select.
 * Picking a language stores it in a cookie, which the server prefers to the browser's Accept-Language
 * header (see Gather::Locales.for_request), and reloads the page in that language. Picking "Browser
 * Default" deletes the cookie so the browser's language applies again.
 */
export default class extends Controller<HTMLElement> {
  static targets = ["link", "select"];
  static values = {cookie: String, domain: String};

  declare readonly linkTarget: HTMLElement;
  declare readonly selectTarget: HTMLSelectElement;
  declare readonly cookieValue: string;
  declare readonly domainValue: string;

  show(event: Event): void {
    event.preventDefault();
    this.linkTarget.classList.add("hidden");
    this.selectTarget.classList.remove("hidden");
    this.selectTarget.focus();
  }

  choose(): void {
    const locale = this.selectTarget.value;
    /*
     * Same domain as the session cookie, so the choice holds on the apex domain and every community's
     * subdomain.
     */
    const secure = window.location.protocol === "https:" ? "; secure" : "";
    const attributes = `; domain=${this.domainValue}; path=/; samesite=lax${secure}`;
    if (locale) {
      const value = encodeURIComponent(locale);
      document.cookie = `${this.cookieValue}=${value}; max-age=${ONE_YEAR_IN_SECONDS}${attributes}`;
    } else {
      document.cookie = `${this.cookieValue}=; max-age=0${attributes}`;
    }
    // A GET of the current page, not reload(), which would offer to resubmit a form that was just posted.
    window.location.assign(window.location.pathname + window.location.search);
  }
}
