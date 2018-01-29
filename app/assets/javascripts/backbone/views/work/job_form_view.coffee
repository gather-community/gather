Gather.Views.Work.JobFormView = Backbone.View.extend

  initialize: (options) ->
    @formatFields()

  events:
    'cocoon:after-insert': 'shiftInserted'
    'change #work_job_time_type': 'formatFields'

  formatFields: ->
    dateFormat = I18n.t('datepicker.pformat')
    timeFormat = I18n.t('timepicker.pformat')
    time_type = @$('#work_job_time_type').val()
    switch time_type
      when 'date_time' then @setPickerFormat("#{dateFormat} #{timeFormat}")
      when 'date_only', 'full_period' then @setPickerFormat(dateFormat)

  shiftInserted: (event, inserted) ->
    @initDatePickers(inserted)

  initDatePickers: (inserted) ->
    @$(inserted).find('.datetimepicker').datetimepicker()

  setPickerFormat: (format) ->
    @shiftDatePickers().map (picker) ->
      $(this).data('DateTimePicker').format(format)

  shiftDatePickers: ->
    @$('#shift-table .datetimepicker')
