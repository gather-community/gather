Gather.Views.Reservations.ProtocolFormView = Backbone.View.extend
  initialize: (options) ->
    @$('#reservations_protocol_kinds').trigger('change')

  events:
    'change #reservations_protocol_kinds': 'kindsChanged'

  kindsChanged: (event) ->
    kinds = @$(event.target).val()
    @$('.reservations_protocol_requires_kind').toggle(!kinds)
