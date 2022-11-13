// Abstract parent class for views controlling forms.
Gather.Views.FormView = Backbone.View.extend({
  setValidationMessage(input, message, options) {
    options = options || {type: 'error'};
    input.nextAll('.error, .success').remove();
    $('<div>').addClass(options.type).text(message).insertAfter(input);
    if (options.type === 'error') {
      input.closest('.form-group').addClass('has-error');
    } else {
      input.closest('.form-group').removeClass('has-error');
    }
  },

  clearValidationMessage(input) {
    input.nextAll('.error, .success').remove();
    input.closest('.form-group').removeClass('has-error');
  }
});
