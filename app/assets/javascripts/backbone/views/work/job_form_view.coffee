Gather.Views.Work.JobFormView = Backbone.View.extend

  initialize: (options) ->

  events:
    'cocoon:after-insert': 'shiftInserted'

  shiftInserted: (event, inserted) ->
    @initDatePickers(inserted)

  initDatePickers: (inserted) ->
    $(inserted).find(".datetimepicker").datetimepicker()
