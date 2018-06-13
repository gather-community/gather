Gather.Views.Work.JobFormView = Backbone.View.extend

  initialize: (options) ->
    @formatFields()

    # Force reevaluation of all slot counts
    @$(".shift-slots input").trigger("change")

  events:
    'cocoon:after-insert': 'shiftInserted'
    'change #work_job_time_type': 'formatFields'
    'change #work_job_slot_type': 'formatFields'
    'change #work_job_hours': 'computeHours'
    'change #work_job_hours_per_shift': 'computeHours'
    'keyup .shift-slots input': 'handleSlotOrWorkerCountChange'
    'change .shift-slots input': 'handleSlotOrWorkerCountChange'
    'cocoon:after-insert .assignments': 'handleSlotOrWorkerCountChange'
    'dp.change .input-group.datetimepicker': 'computeHours'
    'dp.change .starts-at .input-group.datetimepicker': 'setEndsAtDefault'

  shiftInserted: (event, inserted) ->
    @initDatePickers(inserted)
    @formatFields()

  formatFields: ->
    dateFormat = I18n.t('datepicker.pformat')
    timeFormat = I18n.t('timepicker.pformat')

    @toggleHoursPerShift(@timeType() == 'date_only' && @slotType() == 'full_multiple')
    @togglePickers(@timeType() != 'full_period')
    @toggleUnlimitedSlots(@slotType() != 'fixed')
    @computeHours()

    # Set picker format depending on @timeType()
    switch @timeType()
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

  computeHours: ->
    @$('#shift-rows tr.nested-fields').each (_, row) =>
      @$(row).find('.hours').html(@computeHoursForRow(@$(row)))

  computeHoursForRow: (row) ->
    # date_time jobs always have hours computed from start/end times
    if @timeType() == 'date_time'
      start = row.find('.starts-at .datetimepicker').data("DateTimePicker").date()
      stop = row.find('.ends-at .datetimepicker').data("DateTimePicker").date()
      if start && stop
        Math.round(moment.duration(stop.diff(start)).asHours() * 10) / 10
      else
        ""

    # date_only full_multiple jobs have a special hours per shift box, so we pull from there
    else if @timeType() == 'date_only' && @slotType() == 'full_multiple'
      @$('#work_job_hours_per_shift').val()

    # All other timeType/slotType combos pull straight from job.hours
    else
      @$('#work_job_hours').val()

  setEndsAtDefault: (event) ->
    startPicker = @$(event.currentTarget).closest('.input-group.datetimepicker')
    start = startPicker.data("DateTimePicker").date()
    if (start)
      endPicker = @$(event.currentTarget).closest('tr').find('.ends-at .input-group.datetimepicker')
      endPicker.data("DateTimePicker").defaultDate(start)

  # Toggles add link based on how many slots and workers there are.
  # Can originate from link click or keyup on slots input.
  handleSlotOrWorkerCountChange: (event) ->
    row = @$(event.target).closest(".nested-fields")
    slotsInput = row.find(".shift-slots input")
    assignments = row.find(".assignments")
    workerCount = assignments.find(".work_job_shifts_assignments_user_id").length
    slotCount = if slotsInput.val() then parseInt(slotsInput.val()) else 1
    assignments.find(".add-link").toggle(workerCount < slotCount)

  timeType: ->
    @$('#work_job_time_type').val()

  slotType: ->
    @$('#work_job_slot_type').val()

  hours: ->
    @$('#work_job_hours').val()

  hoursPerShift: ->
    @$('#work_job_hours_per_shift').val()
