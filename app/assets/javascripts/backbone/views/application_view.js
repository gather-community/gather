/*
 * Decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * DS206: Consider reworking classes to avoid initClass
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/main/docs/suggestions.md
 */
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
    return new Gather.Views.Toggler();
  }
});
