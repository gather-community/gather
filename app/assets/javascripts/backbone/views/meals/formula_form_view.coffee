Gather.Views.FormulaFormView = Backbone.View.extend

  initialize: (options) ->
    @updateMeal()
    @updatePantry()

  events:
    'change #meals_formula_meal_calc_type': 'updateMeal'
    'change #meals_formula_pantry_calc_type': 'updatePantry'

  updateMeal: ->
    # if @$('#meals_formula_meal_calc_type').val() == 'fixed'


  updatePantry: ->
