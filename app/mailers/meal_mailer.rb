# frozen_string_literal: true

# For emails related to meals.
class MealMailer < ApplicationMailer
  def meal_reminder(signup)
    @household = signup.household.decorate
    @signup = signup
    @meal = signup.meal.decorate
    @assigns = @meal.assignments

    mail(to: @household, subject: default_i18n_subject(
      title: @meal.title_or_no_title,
      datetime: @meal.served_at_wday_no_year,
      location: @meal.location_abbrv
    ))
  end

  def role_reminder(assignment, reminder)
    @assignment = assignment.decorate
    @user = assignment.user.decorate
    @meal = assignment.meal.decorate
    @reminder = reminder
    @other_assigns = @meal.assignments.reject { |a| a.user == @user }

    mail(to: @user, subject: default_i18n_subject(
      role: assignment.role_title,
      datetime: @assignment.starts_at_with_date,
      location: @meal.location_abbrv,
      note: @reminder.note? ? " (#{@reminder.note})" : ""
    ))
  end

  def worker_change_notice(initiator, meal, added, removed)
    @initiator = initiator
    @meal = meal.decorate
    @added = added
    @removed = removed

    recips = (@meal.assignments + removed).map(&:user)
    recips << @initiator
    recips.concat(User.with_meals_coordinator_role.in_community(@meal.community))

    mail(to: recips.compact.uniq)
  end

  def cook_menu_reminder(assignment)
    @assignment = assignment
    @user = assignment.user.decorate
    @meal = assignment.meal.decorate
    @type = assignment.cook_menu_reminder_count.zero? ? :first : :second

    mail(to: @user, subject: default_i18n_subject(date: @meal.served_on_no_yr))
  end

  def normal_message(message, recipient)
    meal_message(message, recipient)
  end

  def cancellation_message(message, recipient)
    meal_message(message, recipient)
  end

  protected

  def meal_message(message, recipient)
    @message = message
    @recipient = recipient.decorate
    @meal = @message.meal.decorate
    mail(to: @recipient, reply_to: [message.sender_email],
         subject: default_i18n_subject(datetime: @meal.served_on_no_yr))
  end

  def community
    @meal.community
  end
end
