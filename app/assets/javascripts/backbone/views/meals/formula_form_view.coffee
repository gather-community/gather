Gather.Views.Meals.FormulaFormView = Backbone.View.extend

  initialize: (options) ->
    @updateMeal()

  events:
    'change #meals_formula_meal_calc_type': 'updateMeal'
    'select2:select .meals_formula_parts_type_id': 'handleTypeChanged'

  updateMeal: ->
    meal_calc_type = @$('#meals_formula_meal_calc_type').val()
    @$('.formula-part-hints p').hide()
    if meal_calc_type
      @$(".formula-part-hints p.#{meal_calc_type}").show()

  handleTypeChanged: (event) ->
    # If the user types in a new type name, we remove the select2 altogether and show the text box.
    # This ensures the new type name is sent in the right box.
    if event.params.data.newTag
      typeIdWrapper = @$(event.currentTarget)
      nameWrapper = typeIdWrapper.closest(".fields-col").find(".control-wrapper[class$=_type_name]")
      typeIdWrapper.remove()
      nameWrapper.find('input').val(event.params.data.text)
      nameWrapper.show()
