Gather.Views.Calendars.ProtocolFormView = Backbone.View.extend
  initialize: (options) ->
    @$('#calendars_protocol_kinds').trigger('change')

  events:
    'change #calendars_protocol_kinds': 'kindsChanged'

  kindsChanged: (event) ->
    kinds = @$(event.target).val()
    @$('.calendars_protocol_requires_kind').toggle(!kinds)
