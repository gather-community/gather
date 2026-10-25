import {Controller} from "@hotwired/stimulus";
import EasyMDE from "easymde";
import i18n from "../../utils/i18n";

// EasyMDE's own labels are English, so the toolbar buttons and the line and word counts are built here
// with translated text. The class names match EasyMDE's built-in buttons so they look the same.
const BUTTONS: [string, (editor: EasyMDE) => void, string][] = [
  ["bold", EasyMDE.toggleBold, "fa fa-bold"],
  ["italic", EasyMDE.toggleItalic, "fa fa-italic"],
  ["heading", EasyMDE.toggleHeadingSmaller, "fa fa-header fa-heading"],
  ["quote", EasyMDE.toggleBlockquote, "fa fa-quote-left"],
  ["unordered_list", EasyMDE.toggleUnorderedList, "fa fa-list-ul"],
  ["ordered_list", EasyMDE.toggleOrderedList, "fa fa-list-ol"],
  ["link", EasyMDE.drawLink, "fa fa-link"],
  ["image", EasyMDE.drawImage, "fa fa-image"],
  ["preview", EasyMDE.togglePreview, "fa fa-eye"],
  ["side_by_side", EasyMDE.toggleSideBySide, "fa fa-columns"],
  ["fullscreen", EasyMDE.toggleFullScreen, "fa fa-arrows-alt"],
];

// Buttons that stay enabled in preview mode, and those hidden on phones, as in EasyMDE.
const NO_DISABLE = ["preview", "side_by_side", "fullscreen"];
const NO_MOBILE = ["side_by_side", "fullscreen"];

// EasyMDE's word count, which counts each CJK character as a word.
const WORD_PATTERN = new RegExp(
  "[a-zA-Z0-9_\u00A0-\u02AF\u0392-\u03C9\u0410-\u04F9]+|" +
  "[\u4E00-\u9FFF\u3400-\u4DBF\uF900-\uFAFF\u3040-\u309F\uAC00-\uD7AF]+",
  "g",
);

const wordCount = (text: string): number => (text.match(WORD_PATTERN) || [])
  .reduce((count, word) => count + (word.charCodeAt(0) >= 0x4E00 ? word.length : 1), 0);

export default class extends Controller<HTMLTextAreaElement> {
  private editor: EasyMDE;

  connect() {
    const pageId = this.element.dataset.pageId;
    const helpUrl = this.element.dataset.helpUrl;
    this.editor = new EasyMDE({
      element: this.element,
      minHeight: "400px",
      spellChecker: false,
      status: ["cursor", this.countStatus("lines", (text) => text.split("\n").length),
        this.countStatus("words", wordCount), "autosave"],
      renderingConfig: {
        codeSyntaxHighlighting: true,
      },
      toolbar: [
        ...this.buttons(0, 3), "|",
        ...this.buttons(3, 6), "|",
        ...this.buttons(6, 8), "|",
        ...this.buttons(8, 11), "|",
        {
          name: "guide",
          action: helpUrl,
          className: "fa fa-question-circle",
          noDisable: true,
          title: i18n.t("wiki.help"),
        },
      ],
      ...(pageId && {
        autosave: {
          enabled: true,
          uniqueId: `wiki-page-${pageId}`,
          delay: 5000,
          text: i18n.t("wiki.editor.autosaved"),
          timeFormat: {locale: i18n.locale},
        },
      }),
    });
  }

  disconnect() {
    this.editor.toTextArea();
  }

  private buttons(from: number, to: number): EasyMDE.ToolbarButton[] {
    return BUTTONS.slice(from, to).map(([key, action, className]) => ({
      name: key.replace(/_/g, "-"),
      action,
      className,
      title: i18n.t(`wiki.editor.${key}`),
      noDisable: NO_DISABLE.includes(key),
      noMobile: NO_MOBILE.includes(key),
    }));
  }

  // A status bar count like "words: 12". Not EasyMDE's "lines" and "words" classes, whose CSS adds English
  // labels.
  private countStatus(key: string, count: (text: string) => number): EasyMDE.StatusBarItem {
    const show = (el: HTMLElement, text: string) => {
      el.textContent = i18n.t(`wiki.editor.${key}`, {count: count(text)});
    };
    return {
      className: `${key}-count`,
      defaultValue: (el) => show(el, this.element.value),
      onUpdate: (el) => show(el, this.editor.value()),
    };
  }
}
