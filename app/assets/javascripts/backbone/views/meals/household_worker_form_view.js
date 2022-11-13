Gather.Views.Meals.HouseholdWorkerFormView = Backbone.View.extend({
  initialize(options) {
    this.options = options;
  },

  events: {
    'click .delete-assign': 'destroyAssign',
    'ajax:send': 'formSubmitting',
    'ajax:success': 'formSuccess'
  },

  destroyAssign(event) {
    event.preventDefault();

    if (!this.alertShown && this.options.notifyOnWorkerChange) {
      this.alertShown = true;
      if (!confirm(I18n.t('meals/assignments.change_warning'))) {
        return;
      }
    }

    Gather.loadingIndicator.show();
    $.ajax({
      url: event.currentTarget.href,
      method: 'DELETE',
      success: data => {
        this.$el.replaceWith($(data).find('form'));
        Gather.loadingIndicator.hide();
      }
    });
  },

  formSubmitting(e) {
    Gather.loadingIndicator.show();
  },

  formSuccess(e, data) {
    Gather.loadingIndicator.hide();
    this.$el.dirtyForms('setClean');
    this.$el.replaceWith($(data).find('form'));
  }
});
