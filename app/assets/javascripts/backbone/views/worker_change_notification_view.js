Mess.Views.WorkerChangeNotificationView = Backbone.View.extend({
  events: {
    "change": "show"
  },

  show: function() {
    if (!this.showed) {
      alert("Note: If you change meal workers, an email notification will be sent to " +
        "the meals committee/manager and all current and newly assigned workers.");
      this.showed = true;
    }
  }
});
