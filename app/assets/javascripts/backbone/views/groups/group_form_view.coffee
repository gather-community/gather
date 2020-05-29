Gather.Views.Groups.GroupFormView = Backbone.View.extend

  initialize: (options) ->
    @handleAvailabilityChanged()
    @handleListNameChanged()

  events:
    'change #groups_group_availability': 'handleAvailabilityChanged'
    'cocoon:after-insert .groups_group_memberships': 'handleMembershipRowInserted'
    'keyup #groups_group_mailman_list_attributes_name': 'handleListNameChanged'
    'submit': 'handleSubmit'

  handleAvailabilityChanged: ->
    everybody = @everybody()
    @$('.groups_group_memberships .nested-fields').each ->
      kind = $(this).find(".groups_group_memberships_kind select").val()
      $(this).toggle(everybody && kind != 'joiner' || !everybody && kind != 'opt_out')

  handleMembershipRowInserted: (event, row) ->
    if @everybody()
      row.find("option[value=joiner]").remove()
    else
      row.find("option[value=opt_out]").remove()

  everybody: ->
    everybody = @$('.groups_group_availability select').val() == 'everybody'

  handleListNameChanged: ->
    val = @$('#groups_group_mailman_list_attributes_name').val()
    @$('.list-form-details').toggle(val != '')

  handleSubmit: (event) ->
    if @$('#groups_group_mailman_list_attributes__destroy').is(':checked')
      if confirm("Are you sure you want to delete the email list?")
        true
      else
        @$el.data('submitted', false)
        false
    else
      true
