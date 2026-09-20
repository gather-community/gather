import {Controller} from "@hotwired/stimulus";
import {promptModal} from "../utils/modal";

/*
 * Generic "type a token to confirm, then POST a DELETE form" flow, shared by user, household,
 * and community permanent-deletion buttons. The typed value is submitted as `confirmation` and
 * re-validated server-side (the modal is UX only). Replaces the old community_delete_controller.
 */
const PROMPTS: Record<string, {title: string; message: (token: string) => string}> = {
  user: {
    title: "Delete Account",
    message: (token) => "This permanently deletes this account and cannot be undone. " +
      `To confirm, type the person's full name or email: <strong>${token}</strong>`,
  },
  household: {
    title: "Delete Household",
    message: (token) => "This permanently deletes this household and everyone in it, and cannot be undone. " +
      `To confirm, type the household name: <strong>${token}</strong>`,
  },
  community: {
    title: "Delete Community",
    message: (token) => `To permanently delete this community, type its slug: <strong>${token}</strong>`,
  },
};

export default class extends Controller {
  static values = {url: String, confirmToken: String, kind: String};

  declare readonly urlValue: string;
  declare readonly confirmTokenValue: string;
  declare readonly kindValue: string;

  async confirm(event: Event) {
    event.preventDefault();
    event.stopImmediatePropagation();

    const config = PROMPTS[this.kindValue] || PROMPTS.user;
    const typed = await promptModal(config.message(this.confirmTokenValue), {
      title: config.title,
      confirmVariant: "danger",
    });
    if (typed === null) {
      return;
    }

    const form = document.createElement("form");
    form.method = "post";
    form.action = this.urlValue;
    this.appendHidden(form, "_method", "delete");
    this.appendHidden(form, "confirmation", typed);

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
