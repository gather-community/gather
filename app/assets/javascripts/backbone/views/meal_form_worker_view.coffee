# Shows an alert if user attempts to change workers.
Gather.Views.MealFormWorkerView = Backbone.View.extend
  initialize: (options) ->
    @options = options

  events:
    'change #meal_formula_id': 'formulaChanged'
    'change #assignment-fields': 'workersChanged'

  workersChanged: ->
    if !@shown && !@options.notifyOnWorkerChange
      alert('Note: If you change meal workers, an email notification will be sent to ' +
        'the meals committee/manager and all current and newly assigned workers.')
      @shown = true

  formulaChanged: (e) ->
    curFormulaId = $(e.currentTarget).val()
    if @options.newRecord
      $.get "/meals/worker-form", {formula_id: curFormulaId}, (html) =>
        @$('section#workers').replaceWith(html)
        @$('section#workers').trigger('gather:select2inserted', @$('section#workers'))
    else
      origFormulaId = $(e.currentTarget).find('option[selected]').attr('value')
      @$('.formula-change-notice').toggle(origFormulaId != curFormulaId)
