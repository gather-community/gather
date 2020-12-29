// Handles billing template index page.
Gather.Views.Billing.TemplateIndexView = class TemplateIndexView extends Backbone.View {
  get events() {
    return {
      "click .btn-apply": "handleApply",
    };
  }

  handleApply(e) {
    e.preventDefault();
    this.$("form.index-checkbox").submit();
  }
};
