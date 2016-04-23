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

  def worker_change_notice(initiator, meal, added, removed)
    @initiator = initiator
    @meal = meal
    @added = added
    @removed = removed

    recips = (@meal.assignments + removed).map(&:user).map(&:email)
    recips << @meal.host_community.settings[:meals_admin]
    recips << @initiator.email

    mail(to: recips.compact.uniq, subject: "Meal Work Assignment Change Notice")
  end

  def cook_menu_reminder(assignment)
    @assignment = assignment
    @user = assignment.user
    @meal = assignment.meal
    @type = assignment.reminder_count == 0 ? :first : :second

    mail(to: @user.email, subject:
      "Menu Reminder: Please post menu for #{@meal.served_at.to_s(:short_date)}")
  end
end
