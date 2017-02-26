Gather.Views.UserFormView = Backbone.View.extend
  events:
    'click .change-household': 'showHouseholdSelect'
    'click .show-household-fields': 'showHouseholdFields'

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
