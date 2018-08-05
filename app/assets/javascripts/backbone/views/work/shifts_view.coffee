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

  refresh: ->
    $.ajax
      url: window.location.href
      cache: false
      success: (html) => @$(".shifts-main").replaceWith(html)

  handleSignupClick: (event) ->
    card = @$(event.target).closest(".shift-card")
    card.find(".signup-link a").hide()
    card.find(".signup-link .loading-indicator").show()
    event.preventDefault()
    $.ajax
      method: "post"
      url: "/work/signups/#{card.data("id")}/signup"
      success: (response) =>
        @resetRefreshInterval()
        card.replaceWith(response.shift)
        @$(".shifts-synopsis").replaceWith(response.synopsis)
