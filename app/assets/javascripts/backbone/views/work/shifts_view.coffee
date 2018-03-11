Gather.Views.Work.ShiftsView = Backbone.View.extend

  initialize: (options) ->
    @resetRefreshInterval()

  resetRefreshInterval: ->
    clearInterval(@refreshInterval) if @refreshInterval
    @refreshInterval = setInterval(@refresh.bind(this), 5000)

  events:
    "click .signup-link": "handleSignupClick"

  refresh: ->
    $.ajax
      url: window.location.href
      cache: false
      success: (html) => @$(".shifts-main").replaceWith(html)

  handleSignupClick: (event) ->
    card = @$(event.target).closest(".shift-card")
    event.preventDefault()
    $.ajax
      method: "post"
      url: "/work/signups/#{card.data("id")}/signup"
      success: (html) =>
        @resetRefreshInterval()
        card.replaceWith(html)
