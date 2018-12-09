Gather.Views.Work.ShiftsView = Backbone.View.extend

  initialize: (options) ->
    @options = options
    @resetRefreshInterval()

  resetRefreshInterval: ->
    return unless @options.autorefresh
    clearInterval(@refreshInterval) if @refreshInterval
    delay = if window._rails_env == "test" then 1000 else 5000
    @refreshInterval = setInterval(@refresh.bind(this), delay)

  events:
    "click .signup-link": "handleSignupClick"
    "confirm:complete .cancel-link a": "handleCancelClick"

  refresh: ->
    $.ajax
      url: window.location.href
      cache: false
      success: (response) =>
        @$(".shifts-main").replaceWith(response.shifts)
        @$(".pagination").replaceWith(response.pagination)

  handleSignupClick: (event) ->
    card = @$(event.target).closest(".shift-card")
    card.find(".signup-link a").hide()
    card.find(".signup-link .loading-indicator").show()
    event.preventDefault()
    $.ajax
      method: "post"
      url: "/work/signups/#{card.data("id")}/signup"
      success: (response) => @updateShiftAndSynopsis(card, response)

  handleCancelClick: (event, confirmAnswer) ->
    return unless confirmAnswer
    card = @$(event.target).closest(".shift-card")
    link = @$(event.target).closest(".cancel-link")
    link.find("a").hide()
    link.find(".loading-indicator").show()
    event.preventDefault()
    $.ajax
      method: "post"
      url: "/work/signups/#{card.data("id")}/unsignup"
      data: {_method: "delete"}
      success: (response) => @updateShiftAndSynopsis(card, response)

  updateShiftAndSynopsis: (card, response) ->
    @resetRefreshInterval()
    card.replaceWith(response.shift)
    @$(".shifts-synopsis").replaceWith(response.synopsis)
