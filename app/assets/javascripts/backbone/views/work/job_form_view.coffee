Gather.Views.Work.JobFormView = Backbone.View.extend

  initialize: (options) ->
    @formatFields()

  events:
    'cocoon:after-insert': 'shiftInserted'
    'change #work_job_time_type': 'formatFields'

  shiftInserted: (event, inserted) ->
    @initDatePickers(inserted)
    @formatFields()

  formatFields: ->
    dateFormat = I18n.t('datepicker.pformat')
    timeFormat = I18n.t('timepicker.pformat')
    timeType = @$('#work_job_time_type').val()

    @togglePickers(timeType != 'full_period')

    switch timeType
      when 'date_time' then @setPickerFormat("#{dateFormat} #{timeFormat}")
      when 'date_only' then @setPickerFormat(dateFormat)

  initDatePickers: (inserted) ->
    @$(inserted).find('.datetimepicker').datetimepicker()

  setPickerFormat: (format) ->
    @shiftDatePickers().map (picker) ->
      $(this).data('DateTimePicker').format(format)

  shiftDatePickers: ->
    @$('#shift-table .datetimepicker')

  togglePickers: (show) ->
    @shiftDatePickers().toggle(show)
    @$('.period-date').toggle(!show)
