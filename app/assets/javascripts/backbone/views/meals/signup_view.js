Gather.Views.Meals.SignupView = Backbone.View.extend({
  initialize(options) {},

  events: {
    'cocoon:after-insert': 'selectDistinctTypeId'
  },

  selectDistinctTypeId(e) {
    const newLine = this.$(e.target).prev('.nested-fields');
    if (newLine.length === 0) { return; }
    const prevTypeIds = newLine.prevAll('.nested-fields').find('select[name$="[type_id]"]')
      .map(function() { return $(this).val(); }).get();
    newLine.find('select[name$="[type_id]"] option').each(function() {
      const typeId = $(this).attr('value');
      if (prevTypeIds.indexOf(typeId) !== -1) { return true; }
      newLine.find('select[name$="[type_id]"]').val(typeId);
      return false; // Break out of the loop
    });
  }
});
