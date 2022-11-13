Gather.Views.Meals.WorkerChangeNotificationView = Backbone.View.extend({
  initialize(options) {
    this.options = options;
  },

  events: {
    'select2:select': 'workersChanged',
    'select2:unselect': 'workersChanged'
  },

  workersChanged() {
    if (!this.shown && !this.options.newRecord) {
      alert(I18n.t('meals/assignments.change_warning'));
      this.shown = true;
    }
  }
});
