# Shows an alert if user attempts to change workers.
Gather.Views.Meals.WorkerChangeNotificationView = Backbone.View.extend
  initialize: (options) ->
    @options = options

  events:
    'change #meals_meal_formula_id': 'formulaChanged'
    'select2:select': 'workersChanged'
    'select2:unselect': 'workersChanged'

  workersChanged: ->
    if !@shown && !@options.newRecord
      alert(I18n.t('meals/assignments.change_warning'))
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
