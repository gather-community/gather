Gather.Views.Work.PeriodFormView = Backbone.View.extend

  initialize: ->
    @quotaTypeOrPhaseChanged()
    @pickTypeChanged()

  events:
    "change #work_period_quota_type": "quotaTypeOrPhaseChanged"
    "change #work_period_phase": "quotaTypeOrPhaseChanged"
    "change #work_period_pick_type": "pickTypeChanged"
    "click .priority-icon": "priorityChanged"

  quotaTypeOrPhaseChanged: ->
    notNone = @$("#work_period_quota_type").val() != "none"
    @$(".work_period_pick_type").toggle(notNone)
    showShares = notNone && @$("#work_period_phase").val() != "archived"
    @$(".shares").toggle(showShares)
    @$el.toggleClass("full-width", showShares)
    @$el.toggleClass("normal-width", !showShares)

  pickTypeChanged: ->
    staggered = @$("#work_period_pick_type").val() == "staggered"
    @$(".staggering-options").toggle(staggered)
    @$(".priority-icon").toggle(staggered)
    @$(".priority-hint").toggle(staggered)

  priorityChanged: (e) ->
    icon = @$(e.currentTarget)
    newVal = icon.is(".fa-star-o")
    icon.closest(".work-share-selector").find("input[id$=_priority]").val(if newVal then "true" else "false")
    oldClass = if newVal then "fa-star-o" else "fa-star"
    newClass = if newVal then "fa-star" else "fa-star-o"
    icon.removeClass(oldClass).addClass(newClass)
