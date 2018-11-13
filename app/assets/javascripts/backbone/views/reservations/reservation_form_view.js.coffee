Gather.Views.Reservations.ReservationFormView = Backbone.View.extend
  initialize: (options) ->
    @$('#reservations_reservation_kind').trigger('change')

  events:
    'change #reservations_reservation_kind': 'kindChanged'

  kindChanged: (event) ->
    kind = @$(event.target).val()
    @$(".reservations_reservation_pre_notice[data-kinds]").hide()
    @$(".reservations_reservation_pre_notice[data-kinds*=\"{#{kind}}\"]").show()
