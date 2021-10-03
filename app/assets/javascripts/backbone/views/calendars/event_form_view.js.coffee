Gather.Views.Calendars.EventFormView = Backbone.View.extend
  initialize: (options) ->
    @origDatePickerFormat = @$('.datetimepicker input').data('dateOptions').format
    @$('#calendars_event_kind').trigger('change')
    @$('#calendars_event_all_day').trigger('change')

  events:
    'change #calendars_event_kind': 'kindChanged'
    'change #calendars_event_all_day': 'allDayChanged'

  kindChanged: (event) ->
    kind = @$(event.target).val()
    @$(".calendars_event_pre_notice[data-kinds]").hide()
    @$(".calendars_event_pre_notice[data-kinds*=\"{#{kind}}\"]").show()

  allDayChanged: (event) ->
    allDay = @$(event.target).prop('checked')

    # Remove everything after the h: (the time portion) if in all day mode
    format = if allDay then @origDatePickerFormat.replace(/ h:.*$/i, '') else @origDatePickerFormat
    @$('.datetimepicker').each (_, el) =>
      @$(el).data('DateTimePicker').format(format)
