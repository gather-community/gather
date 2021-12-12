# Shows an alert if user attempts to change workers.
Gather.Views.Meals.FormulaChangeView = Backbone.View.extend
  initialize: (options) ->
    @options = options

  events:
    'change #meals_meal_formula_id': 'formulaChanged'

  formulaChanged: (e) ->
    curFormulaId = $(e.currentTarget).val()
    if @options.newRecord
      $.get "/meals/worker-form", {formula_id: curFormulaId}, (html) =>
        @$('section#workers').replaceWith(html)
        @$('section#workers').trigger('gather:select2inserted', @$('section#workers'))
    else
      origFormulaId = $(e.currentTarget).find('option[selected]').attr('value')
      @$('.formula-change-notice').toggle(origFormulaId != curFormulaId)
