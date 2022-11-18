// Handles password form.
Gather.Views.People.PasswordFormView = Gather.Views.FormView.extend({
  events: {
    "change #user_password": "onPasswordChanged",
    "keyup #user_password": "onPasswordChanged",
    "change #user_password_confirmation": "onPasswordConfirmationChanged",
    "keyup #user_password_confirmation": "onPasswordConfirmationChanged"
  },

  onPasswordChanged() {
    (this.debounced || (this.debounced = _.debounce(this.checkStrength, 300)))();
  },

  checkStrength() {
    const input = this.$("#user_password");
    $.ajax({
      url: "/people/password-change/strength",
      method: "post",
      data: {
        password: input.val()
      },
      success(response) {
        const messageType = response.category === "weak" ? "error" : "success";
        const message = I18n.t(`password.strength.${response.category}`, {bits: response.bits});
        const _super = Gather.Views.People.PasswordFormView.__super__;
        _super.setValidationMessage(input, message, {type: messageType});
      }
    });
  },

  onPasswordConfirmationChanged() {
    const input1 = this.$("#user_password");
    const input2 = this.$("#user_password_confirmation");
    const _super = Gather.Views.People.PasswordFormView.__super__;
    if (input1.val() !== input2.val()) {
      const message = I18n.t("errors.messages.doesnt_match");
      _super.setValidationMessage(input2, message);
    } else {
      _super.clearValidationMessage(input2);
    }
  }
});
