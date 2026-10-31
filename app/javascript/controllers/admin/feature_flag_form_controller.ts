import {Controller} from "@hotwired/stimulus";

// Shows the Users field only while "On for selected users" is chosen on the feature flag form.
export default class extends Controller<HTMLElement> {
  static targets = ["usersField"];

  declare readonly usersFieldTarget: HTMLElement;

  toggleUsers(event: Event): void {
    const mode = (event.target as HTMLInputElement).value;
    this.usersFieldTarget.classList.toggle("hidden", mode !== "selected_users");
  }
}
