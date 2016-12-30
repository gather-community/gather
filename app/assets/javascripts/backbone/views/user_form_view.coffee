Mess.Views.UserFormView = Backbone.View.extend
  events:
    'click .change-household': 'showHouseholdSelect'
    'click .edit-household-info': 'showHouseholdFields'

  showHouseholdFields: (e) ->
    e.preventDefault()
    @$('#household-fields').show()
    @$('.form-group.user_household_id').hide()
    @$('#user_household_by_id').val('false')

  showHouseholdSelect: (e) ->
    e.preventDefault()
    @$('#household-fields').hide()
    @$('.form-group.user_household_id').show()
    @$('#user_household_by_id').val('true')
