Gather.Views.Work.PeriodsView = Backbone.View.extend

  initialize: ->
    @handleQuotaTypeChange()

  events:
    "change #work_period_quota_type": "handleQuotaTypeChange"
    "change #work_period_phase": "handleQuotaTypeChange"

  handleQuotaTypeChange: ->
    showShares = @$("#work_period_quota_type").val() != "none" && @$("#work_period_phase").val() != "archived"
    @$(".shares").toggle(showShares)
    @$el.toggleClass("full-width", showShares)
    @$el.toggleClass("normal-width", !showShares)
