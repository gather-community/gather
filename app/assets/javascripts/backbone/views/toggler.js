// Toggles things on and off based on data-toggle, data-toggle-on, data-toggle-off attribs
Gather.Views.Toggler = Backbone.View.extend({
  el: 'body',

  events: {
    'click [data-toggle]': 'toggle'
  },

  toggle(event) {
    const source = this.$(event.currentTarget);
    const id = source.data('toggle');
    const ons = this.$(`[data-toggle-on=\"${id}\"]`);
    const offs = this.$(`[data-toggle-off=\"${id}\"]`);
    const state = ons.length > 0 ? ons.is(':visible') : !offs.is(':visible');
    ons.toggle(!state);
    offs.toggle(state);
    if (source.data("toggle-preserve-link") === false) { source.hide(); }
    event.preventDefault();
  }
});
