Gather.Views.Groups.GroupFormView = Backbone.View.extend

  initialize: (options) ->
    @handleKindChanged()

  events:
    'change #groups_group_kind': 'handleKindChanged'

  handleKindChanged: ->
    kind = @$('.groups_group_kind select').val()
    @$('.groups_group_memberships').toggle(kind != 'everybody')
    @$('.groups_group_opt_outs').toggle(kind == 'everybody')
