# This view is for general functions for the entire app, including admin and frontend
# Should be used sparingly. Prefer separate views (perhaps instantiated from in here)
# for cohesive pieces of functionality.
class Mess.Views.ApplicationView extends Backbone.View

  el: 'body'

  initialize: ->
    Mess.loadingIndicator = @$('#glb-load-ind')
    Mess.errorModal = @$('#glb-error-modal')

    # We prefer to instantiate these ourselves.
    Dropzone.autoDiscover = false

    new Mess.Views.SelectPromptStyler()
