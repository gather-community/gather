Gather.Views.Meals.HouseholdWorkerFormView = Backbone.View.extend
  initialize: (options) ->
    @options = options

  events:
    'click .delete-assign': 'destroyAssign'

  destroyAssign: (event) ->
    event.preventDefault()

    if !@alertShown && @options.notifyOnWorkerChange
      msg = 'Note: If you change meal workers, an email notification will be sent to ' +
        'the meals committee/manager and all current and newly assigned workers.'
      @alertShown = true
      unless confirm(msg)
        return

    Gather.loadingIndicator.show()
    $.ajax
      url: event.currentTarget.href
      method: 'DELETE'
      success: (data) =>
        @$el.replaceWith($(data).find('form'))
        Gather.loadingIndicator.hide()
