Gather.Views.Groups.GroupFormView = Backbone.View.extend

  initialize: (options) ->
    @handleAvailabilityChanged()

  events:
    'change #groups_group_availability': 'handleAvailabilityChanged'

  handleAvailabilityChanged: ->
    availability = @$('.groups_group_availability select').val()
    @$('.groups_group_memberships').toggle(availability != 'everybody')
    @$('.groups_group_opt_outs').toggle(availability == 'everybody')
