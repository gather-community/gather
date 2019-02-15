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
