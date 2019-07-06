Gather.Views.Meals.FormulaFormView = Backbone.View.extend

  initialize: (options) ->
    @updateMeal()

  events:
    'change #meals_formula_meal_calc_type': 'updateMeal'

  updateMeal: ->
    meal_calc_type = @$('#meals_formula_meal_calc_type').val()
    @$('.formula-part-hints p').hide()
    if meal_calc_type
      @$(".formula-part-hints p.#{meal_calc_type}").show()
