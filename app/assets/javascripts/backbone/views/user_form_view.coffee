Gather.Views.UserFormView = Backbone.View.extend
  initialize: ->
    @toggleChildDependentFields()

  events:
    'click .change-household': 'showHouseholdSelect'
    'click .show-household-fields': 'showHouseholdFields'
    'change #user_child': 'toggleChildDependentFields'
    'change #user_full_access': 'toggleChildDependentFields'

  showHouseholdFields: (e) ->
    e.preventDefault()
    @$('.form-group.user_household_id').fadeOut 500, =>
      @$('#household-fields').fadeIn(500)
    @$('#user_household_by_id').val('false')

  showHouseholdSelect: (e) ->
    e.preventDefault()
    @$('#household-fields').fadeOut 500, =>
      @$('.form-group.user_household_id').fadeIn(500)
    @$('#user_household_by_id').val('true')

  toggleChildDependentFields: ->
    child = @$('#user_child').is(':checked')
    was_child = @$('#user_child').data('was-child')
    full_access = @$('#user_full_access').is(':checked')
    @$('.user_full_access').toggle(child)
    @$('.user_roles').toggle(!child || full_access)
    @$('.user_certify_13_or_older').toggle(child && full_access || !child && was_child)
    @$('[data-full-access-only]').toggle(full_access || !child)
    @$('[data-child-only]').toggle(child)
