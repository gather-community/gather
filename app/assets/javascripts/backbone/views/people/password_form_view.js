// Handles password form.
Gather.Views.People.PasswordFormView = Gather.Views.FormView.extend({
  events: {
    "change #user_password": "onPasswordChanged",
    "keyup #user_password": "onPasswordChanged",
    "change #user_password_confirmation": "checkMatch",
    "keyup #user_password_confirmation": "checkMatch",
    "click #reveal-link": "onRevealClicked",
    "click #mask-link": "onMaskClicked",
  },

  onPasswordChanged() {
    (this.debounced || (this.debounced = _.debounce(this.checkStrengthAndMatch.bind(this), 300)))();
  },

  checkStrengthAndMatch() {
    if (this.$("#user_password_confirmation").val()) {
      this.checkMatch();
    }

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

  checkMatch() {
    const input1 = this.$("#user_password");
    const input2 = this.$("#user_password_confirmation");
    const _super = Gather.Views.People.PasswordFormView.__super__;
    if (input1.val() !== input2.val()) {
      const message = I18n.t("errors.messages.doesnt_match");
      _super.setValidationMessage(input2, message);
    } else {
      _super.clearValidationMessage(input2);
    }
  },

  onRevealClicked(event) {
    event.preventDefault();
    this.$("#user_password").get(0).type = "text";
    this.$("#user_password_confirmation").get(0).type = "text";
    this.$("#reveal-link").hide();
    this.$("#mask-link").show();
  },

  onMaskClicked(event) {
    event.preventDefault();
    this.$("#user_password").get(0).type = "password";
    this.$("#user_password_confirmation").get(0).type = "password";
    this.$("#reveal-link").show();
    this.$("#mask-link").hide();
  }
});
