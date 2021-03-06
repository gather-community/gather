# Shows an alert if user attempts to change workers.
Gather.Views.MealWorkerFormView = Backbone.View.extend
  initialize: (options) ->
    @options = options

  events:
    'change #meals_meal_formula_id': 'formulaChanged'
    'change #assignment-fields': 'workersChanged'
    'select2:select': 'select'
    'select2:unselect': 'unselect'

  workersChanged: ->
    if !@shown && !@newRecord && !@options.notifyOnWorkerChange
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

  # In cases where we allowClear, we need to set the _destroy flag when the clear happens or it won't
  # be persisted (if the record is already saved).
  # NOTE: This code could be useful for other nested fields that consist of only select2s.
  # Job shift workers in the work module is an example of this but it uses a model trick currently to
  # handle this. Consider generalizing in future.
  unselect: (e) ->
    @setDestroyFlag(e.target, true)

  # In cases where we allowClear, if we previously set the destroy flag, we need to unset it if
  # a new selection is made.
  select: (e) ->
    @setDestroyFlag(e.target, false)

  # If there is a destroy flag in the current nested field set, set it to the given bool.
  setDestroyFlag: (target, bool) ->
    @$(target).closest('.nested-fields').find('[id$=_destroy]').val(bool.toString())
