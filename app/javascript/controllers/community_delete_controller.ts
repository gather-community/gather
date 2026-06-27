import {Controller} from "@hotwired/stimulus";
import {promptModal} from "../utils/modal";

export default class extends Controller {
  static values = {slug: String, url: String}

  declare readonly slugValue: string
  declare readonly urlValue: string

  async confirm(event: Event) {
    event.preventDefault();
    event.stopImmediatePropagation();

    const typed = await promptModal(
      `To permanently delete this community, type its slug: <strong>${this.slugValue}</strong>`,
      {title: "Delete Community", confirmVariant: "danger"}
    );
    if (typed !== this.slugValue) {
      return;
    }

    const form = document.createElement("form");
    form.method = "post";
    form.action = this.urlValue;

    this.appendHidden(form, "_method", "delete");
    this.appendHidden(form, "community_slug", typed);

    const csrfMeta = document.querySelector<HTMLMetaElement>("meta[name=\"csrf-token\"]");
    if (csrfMeta) {
      this.appendHidden(form, "authenticity_token", csrfMeta.content);
    }

    document.body.appendChild(form);
    form.submit();
  }

  private appendHidden(form: HTMLFormElement, name: string, value: string) {
    const input = document.createElement("input");
    input.type = "hidden";
    input.name = name;
    input.value = value;
    form.appendChild(input);
  }
}
