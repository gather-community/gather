Gather.Views.Meals.ImportResultsView = Backbone.View.extend

  initialize: (options) ->
    Gather.loadingIndicator.show()
    @checkForResults()

  checkForResults: ->
    $.ajax
      url: window.location.href
      cache: false
      success: (response, status) =>
        if status == "nocontent"
          setTimeout(@checkForResults.bind(this), 3000)
        else
          @$el.html(response)
          Gather.loadingIndicator.hide()
