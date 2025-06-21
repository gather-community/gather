Gather.Views.Work.ShiftsView = Backbone.View.extend({
  initialize(options) {
    this.options = options;
    this.resetRefreshInterval();
  },

  resetRefreshInterval() {
    if (!this.options.autorefresh) {
      return;
    }
    if (this.refreshInterval) {
      clearInterval(this.refreshInterval);
    }
    const delay = window._rails_env === "test" ? 1000 : 5000;
    this.refreshInterval = setInterval(this.refresh.bind(this), delay);
  },

  events: {
    "click .signup-link": "handleSignupClick",
    "confirm:complete .cancel-link a": "handleCancelClick"
  },

  refresh() {
    $.ajax({
      url: window.location.href,
      cache: false,
      success: response => {
        this.$(".shifts-main").replaceWith(response.shifts);
        this.$(".pagination-wrapper").replaceWith(response.pagination);
      }
    });
  },

  handleSignupClick(event) {
    const card = this.$(event.target).closest(".shift-card");
    card.find(".signup-link a").hide();
    card.find(".signup-link .loading-indicator").show();
    event.preventDefault();
    $.ajax({
      method: "post",
      url: `/work/signups/${card.data("id")}/signup`,
      success: response => this.updateShiftAndSynopsis(card, response)
    });
  },

  handleCancelClick(event, confirmAnswer) {
    if (!confirmAnswer) {
      return;
    }
    const card = this.$(event.target).closest(".shift-card");
    const link = this.$(event.target).closest(".cancel-link");
    link.find("a").hide();
    link.find(".loading-indicator").show();
    event.preventDefault();
    $.ajax({
      method: "post",
      url: `/work/signups/${card.data("id")}/unsignup`,
      data: {_method: "delete"},
      success: response => this.updateShiftAndSynopsis(card, response)
    });
  },

  updateShiftAndSynopsis(card, response) {
    this.resetRefreshInterval();
    card.replaceWith(response.shift);
    this.$(".shifts-synopsis").replaceWith(response.synopsis);
  }
});
