// Adds a class to select boxes that have prompt currently selected.
// Allows for placeholder-like styling.
// Looks for has-prompt class on select tag.
Gather.Views.SelectPromptStyler = Backbone.View.extend({
  el: 'body',

  initialize() {
    this.$('select.has-prompt').trigger('change');
  },

  events: {
    'change select.has-prompt': 'changed'
  },

  changed(e) {
    const select = this.$(e.currentTarget);
    if (select.find('option').first().is(':selected')) {
      select.addClass('prompt-selected');
    } else {
      select.removeClass('prompt-selected');
    }
  }
});
