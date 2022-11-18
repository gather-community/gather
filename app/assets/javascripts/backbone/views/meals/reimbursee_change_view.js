// Reloads part of the expenses form if reimbursee changes.
Gather.Views.Meals.ReimburseeChangeView = Backbone.View.extend({
  initialize(options) {
    this.options = options;
  },

  events: {
    "change #meals_meal_cost_attributes_reimbursee_id": "reimburseeChanged"
  },

  reimburseeChanged(e) {
    const newReimburseeId = this.$(e.currentTarget).val();
    $.get(this.options.paypalEmailUrl, {user_id: newReimburseeId}, (data) => {
      this.$("#reimbursee-paypal-email").text(data.email);
    });
  }
});
