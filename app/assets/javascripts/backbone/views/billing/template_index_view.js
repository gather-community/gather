// Handles billing template index page.
Gather.Views.Billing.TemplateIndexView = Backbone.View.extend({
  events: {
    "click .btn-apply": "handleApply",
  },

  handleApply(e) {
    e.preventDefault();
    this.$("form.index-checkbox").submit();
  }
});
