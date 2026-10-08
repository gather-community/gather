Gather.Views.CalendarNavLinkPopoverView = Backbone.View.extend({
  initialize() {
    this.showPopover(this.$(".navbar.hidden-xs a[href^=\"/calendars/events\"]"));
  },

  events: {
    "click a[href=\"#dismisspopover\"]": "dismissLinkClicked",
    "shown.bs.collapse": "navbarShown"
  },

  navbarShown(e) {
    if (this.dismissed) {
      return;
    }
    this.showPopover(this.$(e.target).find("a.dropdown-toggle > i.fa-calendar"));
  },

  showPopover($el) {
    $el.popover({
      content: `<div>${I18n.t("calendar_nav_popover.message_html")}</div>` +
        `<div><a href="#dismisspopover">${I18n.t("calendar_nav_popover.dismiss")}</a></div>`,
      html: true,
      placement: "bottom",
      trigger: "manual"
    });
    $el.popover("show");
  },

  dismissLinkClicked(e) {
    e.preventDefault();
    e.stopPropagation();
    this.dismissed = true;
    this.$(e.target).closest(".popover").popover("hide");
    $.ajax({
      url: "/users/update-setting",
      method: "PATCH",
      data: {
        settings: {
          calendar_popover_dismissed: 1
        }
      }
    });
  }
});
