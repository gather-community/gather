import {Controller} from "@hotwired/stimulus";

// Room for the dropdown arrow and padding beyond the text itself.
const CHROME_PX = 34;
// The widest a dropdown may grow, so one long option can't take over the bar.
const MAX_PX = 240;
// Below this width (Bootstrap's $screen-sm-min) the stylesheet makes every dropdown full width.
const MIN_SCREEN_PX = 768;

// Widens each visible dropdown in the form whose selected option doesn't fit, up to MAX_PX.
const widen = (form: HTMLFormElement): void => {
  const context = document.createElement("canvas").getContext("2d");
  if (!context) {
    return;
  }

  form.querySelectorAll("select").forEach((select) => {
    const option = select.options[select.selectedIndex];
    if (!option || !select.offsetParent) {
      return;
    }

    context.font = getComputedStyle(select).font;
    const needed = Math.ceil(context.measureText(option.text).width) + CHROME_PX;
    if (needed > select.offsetWidth) {
      select.style.width = `${Math.min(needed, MAX_PX)}px`;
    }
  });
};

/*
 * The title and the buttons beside it are a table that fills its container, and grows past it when the
 * buttons need more room than is left.
 */
const overflows = (row: HTMLElement): boolean => {
  const container = row.parentElement;
  return !!container && row.getBoundingClientRect().width > container.clientWidth + 1;
};

/*
 * Widens a lens dropdown whose selected option doesn't fit. The stylesheet gives each dropdown a fixed
 * width that suits English, and some languages need more ("Alle gemeenschappen", "Vergangene und
 * künftige"). A dropdown never shrinks, so English keeps its widths. CSS can't size a select to its
 * selected option in every browser (`field-sizing: content` is Chromium-only), hence the measuring.
 *
 * The layout renders the lens bar twice: beside the page title on desktops ("upper") and on its own row
 * below the title on tablets ("lower"). If widening the upper bar would squeeze the title onto another
 * line or push the row past the edge of the page, the lenses move below the title, as on a tablet.
 *
 * Choosing an option submits the form and reloads the page, so sizing once on connect is enough.
 */
export default class extends Controller<HTMLFormElement> {
  connect(): void {
    if (window.innerWidth < MIN_SCREEN_PX) {
      return;
    }

    /*
     * On a tablet the lower bar is the one showing. On a desktop it's hidden, and the upper bar sizes it
     * if it moves the lenses below the title.
     */
    if (this.element.classList.contains("lower")) {
      widen(this.element);
      return;
    }

    const row = this.element.closest<HTMLElement>(".title-and-buttons");
    const title = row?.querySelector<HTMLElement>("h1");
    const titleHeight = title?.offsetHeight ?? 0;

    widen(this.element);

    if (row && title && (title.offsetHeight > titleHeight || overflows(row))) {
      row.classList.add("lenses-below");
      const lower = row.nextElementSibling;
      if (lower instanceof HTMLFormElement && lower.classList.contains("lens-bar")) {
        widen(lower);
      }
    }
  }
}
