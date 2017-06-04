# Simply calls window.print when button clicked.
Gather.Views.PrintView = Backbone.View.extend

  el: '#content'

  events:
    'click button.btn-print': 'print'

  print: ->
    window.print()
