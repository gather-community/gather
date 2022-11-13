Gather.Views.Work.JobFormView = Backbone.View.extend({

  initialize(options) {
    this.formatFields();

    // Force reevaluation of all slot counts
    this.$(".shift-slots input").trigger("change");
  },

  events: {
    'cocoon:after-insert #shifts': 'shiftInserted',
    'change #work_job_time_type': 'formatFields',
    'change #work_job_slot_type': 'formatFields',
    'change #work_job_hours': 'computeHours',
    'change #work_job_hours_per_shift': 'computeHours',
    'keyup .shift-slots input': 'handleSlotOrWorkerCountChange',
    'change .shift-slots input': 'handleSlotOrWorkerCountChange',
    'cocoon:after-insert .assignments': 'handleSlotOrWorkerCountChange',
    'dp.change .input-group.datetimepicker': 'computeHours',
    'dp.change .starts-at .input-group.datetimepicker': 'setEndsAtDefault'
  },

  shiftInserted(event, inserted) {
    this.initDatePickers(inserted);
    this.formatFields();
  },

  formatFields() {
    const dateFormat = I18n.t('datepicker.pformat');
    const timeFormat = I18n.t('timepicker.pformat');

    this.toggleHoursPerShift((this.timeType() === 'date_only') && (this.slotType() === 'full_multiple'));
    this.togglePickers(this.timeType() !== 'full_period');
    this.toggleUnlimitedSlots(this.slotType() !== 'fixed');
    this.computeHours();

    // Set picker format depending on @timeType()
    switch (this.timeType()) {
      case 'date_time': this.setPickerFormat(`${dateFormat} ${timeFormat}`);
      case 'date_only': this.setPickerFormat(dateFormat);
    }
  },

  initDatePickers(inserted) {
    this.$(inserted).trigger('page:change');
  }, // Force recognition of datepicker in pickers.js

  setPickerFormat(format) {
    this.shiftDatePickers().map(function() {
      $(this).data('DateTimePicker').format(format);
    });
  },

  shiftDatePickers() {
    this.$('#shift-table .datetimepicker');
  },

  toggleHoursPerShift(show) {
    this.$('.form-group.work_job_hours_per_shift').toggle(show);
  },

  togglePickers(show) {
    this.shiftDatePickers().toggle(show);
    this.$('.period-date').toggle(!show);
  },

  toggleUnlimitedSlots(show) {
    this.$('.shift-slots').toggle(!show);
    this.$('#shift-table .unlimited').toggle(show);
    if (!show) {
      this.$('.shift-slots').map(function() {
        if (parseInt($(this).val()) >= 1000000) {
          $(this).val('');
        }
      });
    }
  },

  computeHours() {
    this.$('#shift-rows tr.nested-fields').each((_, row) => {
      this.$(row).find('.hours').html(this.computeHoursForRow(this.$(row)));
    });
  },

  computeHoursForRow(row) {
    // date_time jobs always have hours computed from start/end times
    if (this.timeType() === 'date_time') {
      const start = row.find('.starts-at .datetimepicker').data("DateTimePicker").date();
      const stop = row.find('.ends-at .datetimepicker').data("DateTimePicker").date();
      if (start && stop) {
        return Math.round(moment.duration(stop.diff(start)).asHours() * 10) / 10;
      } else {
        return "";
      }

    // date_only full_multiple jobs have a special hours per shift box, so we pull from there
    } else if ((this.timeType() === 'date_only') && (this.slotType() === 'full_multiple')) {
      return this.$('#work_job_hours_per_shift').val();

    // All other timeType/slotType combos pull straight from job.hours
    } else {
      return this.$('#work_job_hours').val();
    }
  },

  setEndsAtDefault(event) {
    const startPicker = this.$(event.currentTarget).closest('.input-group.datetimepicker');
    const start = startPicker.data("DateTimePicker").date();
    if (start) {
      const endPicker = this.$(event.currentTarget).closest('tr').find('.ends-at .input-group.datetimepicker');
      endPicker.data("DateTimePicker").defaultDate(start);
    }
  },

  // Toggles add link based on how many slots and workers there are.
  // Can originate from link click or keyup on slots input.
  handleSlotOrWorkerCountChange(event) {
    const row = this.$(event.target).closest(".nested-fields");
    const slotsInput = row.find(".shift-slots input");
    const assignments = row.find(".assignments");
    const workerCount = assignments.find(".work_job_shifts_assignments_user_id").length;
    const slotCount = slotsInput.val() ? parseInt(slotsInput.val()) : 1;
    assignments.find(".add-link").toggle(workerCount < slotCount);
  },

  timeType() {
    return this.$('#work_job_time_type').val();
  },

  slotType() {
    return this.$('#work_job_slot_type').val();
  },

  hours() {
    return this.$('#work_job_hours').val();
  },

  hoursPerShift() {
    return this.$('#work_job_hours_per_shift').val();
  }
});
