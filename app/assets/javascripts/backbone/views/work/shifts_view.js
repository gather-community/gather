Gather.Views.Work.ShiftsView = Backbone.View.extend({
  initialize(options) {
    this.options = options;

    /*
     * A refresh replaces the whole shift list with markup the server rendered when the refresh
     * request arrived. If that overlaps a signup, it can undo the signup on screen: the markup
     * predates the signup, so applying it puts the "Sign Up!" link back, and the signup looks like
     * it didn't happen until the next refresh lands. So we hold off refreshing while a signup is
     * in flight, and ignore the response of any refresh that a signup started after.
     */
    this.pendingSignups = 0;
    this.signupGeneration = 0;
    this.refreshPending = false;

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
    // Confirmation is handled by the `confirm` Stimulus controller on the link, which re-fires
    // this click once the user confirms. See controllers/confirm_controller.ts.
    "click .cancel-link a": "handleCancelClick"
  },

  refresh() {
    /*
     * A refresh sent now would be rendered against state the pending signup hasn't reached yet. And
     * a second refresh while one is outstanding is worse than useless: the two responses can arrive
     * in either order, so the older list could end up replacing the newer one.
     */
    if (this.pendingSignups > 0 || this.refreshPending) {
      return;
    }
    const generation = this.signupGeneration;
    this.refreshPending = true;
    $.ajax({
      url: window.location.href,
      cache: false,
      success: response => {
        // A signup happened while this was in flight, so the response is out of date. Drop it.
        if (this.signupGeneration !== generation) {
          return;
        }
        this.$(".shifts-main").replaceWith(response.shifts);
        this.$(".pagination-wrapper").replaceWith(response.pagination);
      },
      complete: () => {
        this.refreshPending = false;
      }
    });
  },

  handleSignupClick(event) {
    const card = this.$(event.target).closest(".shift-card");
    card.find(".signup-link a").hide();
    card.find(".signup-link .loading-indicator").show();
    event.preventDefault();
    this.sendSignupRequest(card.data("id"), {
      method: "post",
      url: `/work/${this.options.period}/signups/${card.data("id")}/signup${window.location.search}`
    });
  },

  handleCancelClick(event) {
    const card = this.$(event.target).closest(".shift-card");
    const link = this.$(event.target).closest(".cancel-link");
    link.find("a").hide();
    link.find(".loading-indicator").show();
    event.preventDefault();
    this.sendSignupRequest(card.data("id"), {
      method: "post",
      url: `/work/${this.options.period}/signups/${card.data("id")}/unsignup${window.location.search}`,
      data: {_method: "delete"}
    });
  },

  sendSignupRequest(shiftId, options) {
    this.pendingSignups += 1;
    this.signupGeneration += 1;
    $.ajax($.extend({}, options, {
      success: response => this.updateShiftAndSynopsis(shiftId, response),
      complete: () => {
        this.pendingSignups -= 1;
      }
    }));
  },

  updateShiftAndSynopsis(shiftId, response) {
    this.resetRefreshInterval();
    /*
     * Look the card up again rather than reusing the element we had on click: a refresh that landed
     * in the meantime will have detached it, and replacing a detached element is a no-op.
     */
    this.$(`.shift-card[data-id='${shiftId}']`).replaceWith(response.shift);
    this.$(".shifts-synopsis").replaceWith(response.synopsis);
  }
});
