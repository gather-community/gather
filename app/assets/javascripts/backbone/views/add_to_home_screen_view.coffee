# Manages add to home screen button.
Gather.Views.AddToHomeScreenView = Backbone.View.extend
  initialize: ->
    window.addEventListener('beforeinstallprompt', (e) =>
      # Prevent Chrome 67 and earlier from automatically showing the prompt
      e.preventDefault()
      unless window.localStorage.getItem('dontAddToHomeScreen')
        # Stash the event so it can be triggered later.
        @deferredPrompt = e
        # Update UI notify the user they can add to home screen
        @$el.show()
    )
  events:
    'click .btn': 'add'
    'click .opt-out': 'optOut'

  add: ->
    # Hide our user interface that shows our A2HS button
    @$el.hide()
    # Show the prompt
    @deferredPrompt.prompt()
    # Wait for the user to respond to the prompt
    @deferredPrompt.userChoice.then((choiceResult) =>
      if choiceResult.outcome == 'accepted'
        console.log('User accepted the A2HS prompt')
      else
        console.log('User dismissed the A2HS prompt')
      @deferredPrompt = null
    )

  optOut: (e) ->
    e.preventDefault()
    @$el.hide()
    window.localStorage.setItem('dontAddToHomeScreen', true)
