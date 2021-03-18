Gather.Views.Calendars.EventFormView = Backbone.View.extend
  initialize: (options) ->
    @$('#calendars_event_kind').trigger('change')

  events:
    'change #calendars_event_kind': 'kindChanged'

  kindChanged: (event) ->
    kind = @$(event.target).val()
    @$(".calendars_event_pre_notice[data-kinds]").hide()
    @$(".calendars_event_pre_notice[data-kinds*=\"{#{kind}}\"]").show()
