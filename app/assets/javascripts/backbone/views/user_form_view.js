Gather.Views.UserFormView = Backbone.View.extend({
  initialize() {
    this.toggleChildDependentFields();
  },

  events: {
    'click .change-household': 'showHouseholdSelect',
    'click .show-household-fields': 'showHouseholdFields',
    'change #user_child': 'toggleChildDependentFields',
    'change #user_full_access': 'toggleChildDependentFields'
  },

  showHouseholdFields(e) {
    e.preventDefault();
    this.$('.form-group.user_household_id').fadeOut(500, () => {
      this.$('#household-fields').fadeIn(500);
    });
    this.$('#user_household_by_id').val('false');
  },

  showHouseholdSelect(e) {
    e.preventDefault();
    this.$('#household-fields').fadeOut(500, () => {
      this.$('.form-group.user_household_id').fadeIn(500);
    });
    this.$('#user_household_by_id').val('true');
  },

  toggleChildDependentFields() {
    const child = this.$('#user_child').is(':checked');
    const was_child = this.$('#user_child').data('was-child');
    const full_access = this.$('#user_full_access').is(':checked');
    this.$('.user_full_access').toggle(child);
    this.$('.user_roles').toggle(!child || full_access);
    this.$('.user_certify_13_or_older').toggle((child && full_access) || (!child && was_child));
    this.$('[data-full-access-only]').toggle(full_access || !child);
    this.$('[data-child-only]').toggle(child);
  }
});
