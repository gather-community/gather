# Shows an alert if user attempts to change workers.
Gather.Views.Meals.WorkerChangeNotificationView = Backbone.View.extend
  initialize: (options) ->
    @options = options

  events:
    'select2:select': 'workersChanged'
    'select2:unselect': 'workersChanged'

  workersChanged: ->
    if !@shown && !@options.newRecord
      alert(I18n.t('meals/assignments.change_warning'))
      @shown = true
