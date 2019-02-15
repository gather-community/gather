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
    if !@options.newRecord
      origFormula = $(e.currentTarget).find("option[selected]").attr("value")
      curFormula = $(e.currentTarget).val()
      @$('.formula-change-notice').toggle(origFormula != curFormula)
