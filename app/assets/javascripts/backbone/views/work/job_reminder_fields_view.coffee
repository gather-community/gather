Gather.Views.Work.JobReminderFieldsView = Backbone.View.extend

  initialize: ->
    # Force reevaluation of all slot counts
    @$("select[id$=_abs_rel]").trigger("change")

  events:
    "change select[id$=_abs_rel]": "absRelChanged"
    "cocoon:after-insert": "reminderInserted"

  absRelChanged: (event) ->
    @toggleFields(@$(event.target).closest(".nested-fields"))

  reminderInserted: (event, inserted) ->
    row = @$(inserted)
    row.find('.datetimepicker').datetimepicker()
    @toggleFields(row)

  toggleFields: (row) ->
    isAbsTime = row.find("select[id$=_abs_rel]").val() == "absolute"
    row.find(".abs-time").toggle(isAbsTime)
    row.find(".rel-time").toggle(!isAbsTime)
