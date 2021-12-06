Gather.Views.Meals.HouseholdWorkerFormView = Backbone.View.extend
  initialize: (options) ->
    @options = options

  events:
    'click .delete-assign': 'destroyAssign'
    'ajax:send': 'formSubmitting'
    'ajax:success': 'formSuccess'

  destroyAssign: (event) ->
    event.preventDefault()

    if !@alertShown && @options.notifyOnWorkerChange
      @alertShown = true
      unless confirm(I18n.t('meals/assignments.change_warning'))
        return

    Gather.loadingIndicator.show()
    $.ajax
      url: event.currentTarget.href
      method: 'DELETE'
      success: (data) =>
        @$el.replaceWith($(data).find('form'))
        Gather.loadingIndicator.hide()

  formSubmitting: (e) ->
    Gather.loadingIndicator.show()

  formSuccess: (e, data) ->
    Gather.loadingIndicator.hide()
    @$el.dirtyForms('setClean')
    @$el.replaceWith($(data).find('form'))
