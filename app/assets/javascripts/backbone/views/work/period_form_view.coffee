Gather.Views.Work.PeriodFormView = Backbone.View.extend

  initialize: ->
    @quotaTypeOrPhaseChanged()
    @pickTypeChanged()

  events:
    "change #work_period_quota_type": "quotaTypeOrPhaseChanged"
    "change #work_period_phase": "quotaTypeOrPhaseChanged"
    "change #work_period_auto_open_time": "autoOpenTimeChanged"
    "change #work_period_pick_type": "pickTypeChanged"

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
