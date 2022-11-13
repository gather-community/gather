Gather.Views.Calendars.IndexView = Backbone.View.extend({
  events: {
    'click .move-links a': 'moveLinkClicked'
  },

  moveLinkClicked(event) {
    event.stopPropagation();
    event.preventDefault();
    const href = this.$(event.currentTarget).attr('href');
    $.ajax({
      url: href,
      method: 'post',
      data: {
        _method: 'put'
      },
      success: response => {
        this.$('table.index').replaceWith(response);
      }
    });
  }
});
