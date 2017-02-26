class DeviseMailer < Devise::Mailer
  def reset_password_instructions(record, token, opts={})
    mail = super
    # your custom logic
    mail.subject = "Invitation to Gather: Meals Electronic Signup System"
    mail
  end
end
