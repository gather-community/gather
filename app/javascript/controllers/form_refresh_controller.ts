import {Controller} from "@hotwired/stimulus";

// A <turbo-stream> element. render() applies its action, or returns the same promise if it has started.
interface StreamElement extends HTMLElement {
  render(): Promise<void>;
}

/*
 * Keeps the parts of a form that depend on other fields up to date, by asking the server to render
 * them again for the form's current values. Rendering stays on the server, in the same partials the
 * page is built from, so the options, rules and wording shown are worked out in one place.
 *
 * Put it on the <form> with a url value. Fields whose change affects other parts of the form call
 * refresh (e.g. data-action="change->form-refresh#refresh"). The whole form is posted to the url,
 * which saves nothing and responds with Turbo Stream actions, usually a morph of each section it
 * rendered, so focus and anything the user hasn't touched survive.
 *
 * Changes in quick succession are sent as one request, and only the latest request's answer is
 * applied, so a slow answer can't overwrite a newer one. When it's applied, a form-refresh:refreshed
 * event is sent from the form, so other controllers can reapply their own state to the new markup.
 */
export default class extends Controller<HTMLFormElement> {
  static values = {url: String, delay: {type: Number, default: 250}};

  declare readonly urlValue: string;
  declare readonly delayValue: number;

  private timer: number | undefined;
  private abort: AbortController | null = null;

  disconnect() {
    window.clearTimeout(this.timer);
    this.abort?.abort();
  }

  refresh() {
    window.clearTimeout(this.timer);
    this.timer = window.setTimeout(() => this.send(), this.delayValue);
  }

  private async send() {
    this.abort?.abort();
    const abort = new AbortController();
    this.abort = abort;

    const body = new FormData(this.element);
    // An edit form sends _method=patch, which would route this to the update action.
    body.delete("_method");

    let html: string;
    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        body,
        signal: abort.signal,
        headers: {Accept: "text/vnd.turbo-stream.html"},
        credentials: "same-origin",
      });
      if (!response.ok) {
        throw new Error(`Form refresh failed with status ${response.status}`);
      }
      html = await response.text();
    } catch (error) {
      if (abort.signal.aborted) {
        return;
      }
      // Leaves the form as it is. The server checks everything again when it's submitted.
      throw error;
    }
    if (abort.signal.aborted) {
      return;
    }
    await this.render(html);
    this.dispatch("refreshed");
  }

  /*
   * Does what Turbo.renderStreamMessage does, but waits for the actions to be applied, which Turbo
   * does on the next animation frame and doesn't announce.
   */
  private async render(html: string) {
    const template = document.createElement("template");
    template.innerHTML = html;
    const streams = Array.from(template.content.querySelectorAll<StreamElement>("turbo-stream"));
    // Connecting each one starts its render.
    streams.forEach((stream) => document.documentElement.appendChild(stream));
    await Promise.all(streams.map((stream) => stream.render()));
  }
}
