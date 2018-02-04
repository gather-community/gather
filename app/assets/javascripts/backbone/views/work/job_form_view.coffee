Gather.Views.Work.JobFormView = Backbone.View.extend

  initialize: (options) ->
    @formatFields()

  events:
    'cocoon:after-insert': 'shiftInserted'
    'change #work_job_time_type': 'formatFields'
    'change #work_job_slot_type': 'formatFields'

  shiftInserted: (event, inserted) ->
    @initDatePickers(inserted)
    @formatFields()

  formatFields: ->
    dateFormat = I18n.t('datepicker.pformat')
    timeFormat = I18n.t('timepicker.pformat')
    timeType = @$('#work_job_time_type').val()
    slotType = @$('#work_job_slot_type').val()

    @toggleHoursPerShift(timeType == 'date_only' && slotType == 'full_multiple')
    @togglePickers(timeType != 'full_period')
    @toggleUnlimitedSlots(slotType != 'fixed')

    # Set picker format depending on timeType
    switch timeType
      when 'date_time' then @setPickerFormat("#{dateFormat} #{timeFormat}")
      when 'date_only' then @setPickerFormat(dateFormat)

  initDatePickers: (inserted) ->
    @$(inserted).find('.datetimepicker').datetimepicker()

  setPickerFormat: (format) ->
    @shiftDatePickers().map ->
      $(this).data('DateTimePicker').format(format)

  shiftDatePickers: ->
    @$('#shift-table .datetimepicker')

  toggleHoursPerShift: (show) ->
    @$('.form-group.work_job_hours_per_shift').toggle(show)

  togglePickers: (show) ->
    @shiftDatePickers().toggle(show)
    @$('.period-date').toggle(!show)

  toggleUnlimitedSlots: (show) ->
    @$('.shift-slots').toggle(!show)
    @$('#shift-table .unlimited').toggle(show)
    if !show
      @$('.shift-slots').map ->
        if parseInt($(this).val()) >= 1000000
          $(this).val('')
