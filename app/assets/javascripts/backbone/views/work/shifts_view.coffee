Gather.Views.Work.ShiftsView = Backbone.View.extend

  initialize: (options) ->
    @refreshInterval = setInterval(@refresh.bind(this), 5000)

  refresh: ->
    $.ajax
      url: window.location.href
      cache: false
      success: (html) => @$(".shifts-main").replaceWith(html)
