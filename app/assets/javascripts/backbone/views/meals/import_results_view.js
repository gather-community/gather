Gather.Views.Meals.ImportResultsView = Backbone.View.extend({
  initialize(options) {
    Gather.loadingIndicator.show();
    this.checkForResults();
  },

  checkForResults() {
    $.ajax({
      url: window.location.href,
      cache: false,
      success: (response, status) => {
        if (status === "nocontent") {
          setTimeout(this.checkForResults.bind(this), 3000);
        } else {
          this.$el.html(response);
          Gather.loadingIndicator.hide();
        }
      }
    });
  }
});
