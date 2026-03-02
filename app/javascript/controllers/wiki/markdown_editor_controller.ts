import { Controller } from "@hotwired/stimulus";
import EasyMDE from "easymde";

export default class extends Controller<HTMLTextAreaElement> {
  private editor: EasyMDE;

  connect() {
    const pageId = this.element.dataset.pageId;
    const helpUrl = this.element.dataset.helpUrl;
    this.editor = new EasyMDE({
      element: this.element,
      minHeight: "400px",
      spellChecker: false,
      status: ["cursor", "lines", "words", "autosave"],
      renderingConfig: {
        codeSyntaxHighlighting: true,
      },
      toolbar: [
        "bold", "italic", "heading", "|",
        "quote", "unordered-list", "ordered-list", "|",
        "link", "image", "|",
        "preview", "side-by-side", "fullscreen", "|",
        { name: "guide", action: helpUrl, className: "fa fa-question-circle", noDisable: true, title: "Wiki Help" },
      ],
      ...(pageId && {
        autosave: {
          enabled: true,
          uniqueId: `wiki-page-${pageId}`,
          delay: 5000,
        },
      }),
    });
  }

  disconnect() {
    this.editor.toTextArea();
  }
}
