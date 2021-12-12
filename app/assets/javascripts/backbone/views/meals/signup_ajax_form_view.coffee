Gather.Views.Meals.SignupAjaxFormView = Backbone.View.extend
  initialize: (options) ->
    if options.ajaxSuccess
      setTimeout(@hideSuccess.bind(this), 2000)

  events:
    'ajax:send': 'formSubmitting'
    'ajax:success': 'formSuccess'

  formSubmitting: (e) ->
    Gather.loadingIndicator.show()

  formSuccess: (e, data) ->
    Gather.loadingIndicator.hide()
    @$el.dirtyForms('setClean')
    if data.redirect
      window.location.href = data.redirect
    else
      @$el.replaceWith($(data).find('form'))

  hideSuccess: ->
    @$('.alert-success').remove()
