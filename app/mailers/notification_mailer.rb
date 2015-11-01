class NotificationMailer < ActionMailer::Base

  default from: Rails.configuration.x.from_email

  def meal_reminder(user, signup)
    @user = user
    @signup = signup
    @meal = signup.meal

    title = @meal.title ? "#{@meal.title}, " : ""

    mail(to: @user.email, subject:
      "Meal Reminder: #{title}#{@meal.served_at.to_s(:datetime_no_yr)} at #{@meal.location_abbrv}")
  end

  def shift_reminder(assignment)
    @assignment = assignment
    @user = assignment.user
    @meal = assignment.meal
    @role = I18n.t("assignment_roles.#{assignment.role}")
    @other_assigns = @meal.assignments.sort.reject{ |a| a.user == @user }

    mail(to: @user.email, subject:
      "Work Reminder: You are #{@role} for meal at #{@meal.served_at.to_s(:datetime_no_yr)} at #{@meal.location_abbrv}")
  end

  def invoice_notice(invoice)
    @invoice = invoice
    @account = invoice.account
    @household = invoice.household

    mail(to: @household.users.map(&:email), subject: "New Invoice")
  end
end
