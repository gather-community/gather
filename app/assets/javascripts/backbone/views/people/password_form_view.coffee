# Handles password form.
Gather.Views.People.PasswordFormView = Gather.Views.FormView.extend

  events:
    'change #user_password': 'onPasswordChanged'
    'keyup #user_password': 'onPasswordChanged'
    'change #user_password_confirmation': 'onPasswordConfirmationChanged'
    'keyup #user_password_confirmation': 'onPasswordConfirmationChanged'

  onPasswordChanged: ->
    (@debounced ||= _.debounce(@checkStrength, 300))()

  checkStrength: ->
    input = @$('#user_password')
    $.ajax
      url: '/people/password-change/strength'
      method: 'post'
      data:
        password: input.val()
      success: (response) ->
        messageType = if response.category == 'weak' then 'error' else 'success'
        message = I18n.t("password.strength.#{response.category}", bits: response.bits)
        _super = Gather.Views.People.PasswordFormView.__super__
        _super.setValidationMessage(input, message, type: messageType)

  onPasswordConfirmationChanged: ->
    input1 = @$('#user_password')
    input2 = @$('#user_password_confirmation')
    _super = Gather.Views.People.PasswordFormView.__super__
    if input1.val() != input2.val()
      message = I18n.t("errors.messages.doesnt_match")
      _super.setValidationMessage(input2, message)
    else
      _super.clearValidationMessage(input2)
