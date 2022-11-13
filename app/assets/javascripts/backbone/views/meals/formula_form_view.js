Gather.Views.Meals.FormulaFormView = Backbone.View.extend({

  initialize(options) {
    this.updateMeal();
  },

  events: {
    'change #meals_formula_meal_calc_type': 'updateMeal',
    'select2:select .meals_formula_parts_type_id': 'handleTypeChanged'
  },

  updateMeal() {
    const meal_calc_type = this.$('#meals_formula_meal_calc_type').val();
    this.$('.formula-part-hints div').hide();
    if (meal_calc_type) {
      this.$(`.formula-part-hints div.${meal_calc_type}`).show();
    }
  },

  handleTypeChanged(event) {
    // If the user types in a new type name, we remove the select2 altogether and show the text box.
    // This ensures the new type name is sent in the right box.
    if (event.params.data.newTag) {
      const typeIdWrapper = this.$(event.currentTarget);
      const nameWrapper = typeIdWrapper.closest(".fields-col").find(".control-wrapper[class$=_type_name]");
      typeIdWrapper.remove();
      nameWrapper.find('input').val(event.params.data.text);
      nameWrapper.show();
    }
  }
});
