class MealMailer < ApplicationMailer
  def meal_reminder(signup)
    @household = signup.household.decorate
    @signup = signup
    @meal = signup.meal.decorate

    mail(to: @household, subject: default_i18n_subject(
      title: @meal.title_or_no_title,
      datetime: @meal.served_at_datetime_no_yr,
      location: @meal.location_abbrv
    ))
  end

  def shift_reminder(assignment)
    @assignment = assignment
    @user = assignment.user.decorate
    @meal = assignment.meal.decorate
    @role = I18n.t("assignment_roles.#{assignment.role}", count: 1)
    @other_assigns = @meal.assignments.sort.reject{ |a| a.user == @user }
    @date = I18n.l(@assignment.starts_at, format: :date_wkday_no_yr)
    @datetime = I18n.l(@assignment.starts_at, format: :datetime_no_yr)
    @shift_start = I18n.l(@assignment.starts_at, format: :regular_time)
    @shift_end = I18n.l(@assignment.ends_at, format: :regular_time)
    @serve_time = I18n.l(@meal.served_at, format: :regular_time)

    mail(to: @user, subject: default_i18n_subject(
      role: @role,
      datetime: @datetime,
      location: @meal.location_abbrv
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
    @type = assignment.reminder_count == 0 ? :first : :second

    mail(to: @user, subject: default_i18n_subject(
      date: @meal.served_at_short_date
    ))
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
      subject: default_i18n_subject(datetime: @meal.served_at_shorter_date))
  end

  def community
    @meal.community
  end
end
