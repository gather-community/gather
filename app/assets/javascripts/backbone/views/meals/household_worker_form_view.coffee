Gather.Views.Meals.HouseholdWorkerFormView = Backbone.View.extend
  initialize: (options) ->

  events:
    'click .delete-assign': 'destroyAssign'

  destroyAssign: (event) ->
    Gather.loadingIndicator.show()
    event.preventDefault()
    $.ajax
      url: event.currentTarget.href
      method: 'DELETE'
      success: (data) =>
        @$el.replaceWith($(data).find('form'))
        Gather.loadingIndicator.hide()
