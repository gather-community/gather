Gather.Views.Meals.HouseholdWorkerFormView = Backbone.View.extend({
  initialize(options) {
    this.options = options;
  },

  events: {
    "click .delete-assign": "destroyAssign",
    "ajax:send": "formSubmitting",
    "ajax:success": "formSuccess"
  },

  destroyAssign(event) {
    event.preventDefault();
    const url = event.currentTarget.href;

    if (!this.alertShown && this.options.notifyOnWorkerChange) {
      this.alertShown = true;
      window.Modal.confirmModal(I18n.t("meals/assignments.change_warning")).then(ok => {
        if (ok) this.performDestroyAssign(url);
      });
    } else {
      this.performDestroyAssign(url);
    }
  },

  performDestroyAssign(url) {
    Gather.loadingIndicator.show();
    $.ajax({
      url: url,
      method: "DELETE",
      success: data => {
        this.$el.replaceWith($(data).find("form"));
        Gather.loadingIndicator.hide();
      }
    });
  },

  formSubmitting(e) {
    Gather.loadingIndicator.show();
  },

  formSuccess(e, data) {
    Gather.loadingIndicator.hide();
    this.$el.dirtyForms("setClean");
    this.$el.replaceWith($(data).find("form"));
  }
});
