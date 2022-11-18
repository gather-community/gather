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
      content: "<div><b>Reservations</b> is now called <b>Calendars</b>! " +
        "Check it out!</div><div><a href=\"#dismisspopover\">Dismiss</a></div>",
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
