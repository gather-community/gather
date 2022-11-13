Gather.Views.Meals.FormulaChangeView = Backbone.View.extend({
  initialize(options) {
    this.options = options;
  },

  events: {
    'change #meals_meal_formula_id': 'formulaChanged'
  },

  formulaChanged(e) {
    const curFormulaId = $(e.currentTarget).val();
    if (this.options.newRecord) {
      $.get("/meals/worker-form", {formula_id: curFormulaId}, html => {
        this.$('section#workers').replaceWith(html);
        this.$('section#workers').trigger('gather:select2inserted', this.$('section#workers'));
      });
    } else {
      const origFormulaId = $(e.currentTarget).find('option[selected]').attr('value');
      this.$('.formula-change-notice').toggle(origFormulaId !== curFormulaId);
    }
  }
});
