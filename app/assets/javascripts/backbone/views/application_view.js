/*
 * This view is for general functions for the entire app, including admin and frontend
 * Should be used sparingly. Prefer separate views (perhaps instantiated from in here)
 * for cohesive pieces of functionality.
 */
Gather.Views.ApplicationView = Backbone.View.extend({
  el: "body",

  initialize() {
    Gather.loadingIndicator = this.$("#glb-load-ind");
    Gather.errorModal = this.$("#glb-error-modal");

    // We prefer to instantiate these ourselves.
    Dropzone.autoDiscover = false;

    new Gather.Views.SelectPromptStyler();
    new Gather.Views.Toggler();
  }
});
