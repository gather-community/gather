class NotificationMailer < ActionMailer::Base

  default from: Rails.configuration.x.from_email

  # Sends a meal notification
  def meal_reminder(user, signup)
    @user = user
    @signup = signup
    @meal = signup.meal

    title = @meal.title ? "#{@meal.title}, " : ""

    mail(to: @user.email, subject:
      "Meal Reminder: #{title}#{@meal.served_at.to_s(:datetime_no_yr)} at #{@meal.location_abbrv}")
  end
end
