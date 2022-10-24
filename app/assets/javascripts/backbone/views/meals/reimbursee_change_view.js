// Reloads part of the expenses form if reimbursee changes.
Gather.Views.Meals.ReimburseeChangeView = class ExportView extends Backbone.View {
  initialize(options) {
    this.options = options;
  }

  get events() {
    return {
      "change #meals_meal_cost_attributes_reimbursee_id": "reimburseeChanged"
    };
  }

  reimburseeChanged(e) {
    const newReimburseeId = this.$(e.currentTarget).val();
    $.get(this.options.paypalEmailUrl, {user_id: newReimburseeId}, (data) => {
      this.$("#reimbursee-paypal-email").text(data.email);
    });
  }
};
