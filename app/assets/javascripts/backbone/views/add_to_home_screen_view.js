// Manages add to home screen button.
Gather.Views.AddToHomeScreenView = Backbone.View.extend({
  initialize(options) {
    this.options = options;
    window.addEventListener('beforeinstallprompt', event => {
      // Prevent Chrome 67 and earlier from automatically showing the prompt
      event.preventDefault();
      if (!this.optedOut()) {
        // Stash the event so it can be triggered later.
        this.deferredPrompt = event;
        // Update UI notify the user they can add to home screen
        this.$el.show();
      }
    });
  },

  events: {
    'click .btn': 'add',
    'click .opt-out': 'optOut'
  },

  add() {
    // Hide our user interface that shows our A2HS button
    this.$el.hide();
    // Show the prompt
    this.deferredPrompt.prompt();
    // Wait for the user to respond to the prompt. We need to handle this event for it to work, I think.
    this.deferredPrompt.userChoice.then(choiceResult => {
      if (choiceResult.outcome === 'accepted') {
        console.log('User accepted the A2HS prompt');
      } else {
        console.log('User dismissed the A2HS prompt');
      }
      this.deferredPrompt = null;
    });
  },

  optOut(event) {
    event.preventDefault();
    this.$el.hide();
    document.cookie = `dontAddToHomeScreen=1;domain=.${this.options.host};` +
      "path=/;expires=Tue, 19 Jan 2038 03:14:07 UTC;";
  },

  optedOut() {
    if (window.localStorage.getItem('dontAddToHomeScreen')) { return true; } // Legacy
    if (document.cookie.indexOf('dontAddToHomeScreen=1') !== -1) { return true; }
    return false;
  }
});
