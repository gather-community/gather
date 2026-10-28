import {Controller} from "@hotwired/stimulus";

// Room for the dropdown arrow and padding beyond the text itself.
const CHROME_PX = 34;
// The widest a dropdown may grow, so one long option can't take over the bar.
const MAX_PX = 240;
// Below this width (Bootstrap's $screen-sm-min) the stylesheet makes every dropdown full width.
const MIN_SCREEN_PX = 768;

/*
 * Widens a lens dropdown whose selected option doesn't fit. The stylesheet gives each dropdown a fixed
 * width that suits English, and some languages need more ("Alle gemeenschappen", "Vergangene und
 * künftige"). A dropdown never shrinks, so English keeps its widths. CSS can't size a select to its
 * selected option in every browser (`field-sizing: content` is Chromium-only), hence the measuring.
 *
 * Choosing an option submits the form and reloads the page, so sizing once on connect is enough.
 */
export default class extends Controller<HTMLFormElement> {
  connect(): void {
    if (window.innerWidth < MIN_SCREEN_PX) {
      return;
    }
    const context = document.createElement("canvas").getContext("2d");
    if (!context) {
      return;
    }

    this.element.querySelectorAll("select").forEach((select) => {
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
  }
}
