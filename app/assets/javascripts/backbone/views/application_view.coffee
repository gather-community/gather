# This view is for general functions for the entire app, including admin and frontend
# Should be used sparingly. Prefer separate views (perhaps instantiated from in here)
# for cohesive pieces of functionality.
class Gather.Views.ApplicationView extends Backbone.View

  el: 'body'

  initialize: ->
    Gather.loadingIndicator = @$('#glb-load-ind')
    Gather.errorModal = @$('#glb-error-modal')

    # We prefer to instantiate these ourselves.
    Dropzone.autoDiscover = false

    new Gather.Views.SelectPromptStyler()
