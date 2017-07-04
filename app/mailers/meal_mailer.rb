class MealMailer < ApplicationMailer
  def meal_reminder(signup)
    @household = signup.household
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
    @user = assignment.user
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
    recips << @meal.community.settings.meals.admin_email
    recips << @initiator

    mail(to: recips.compact.uniq)
  end

  def cook_menu_reminder(assignment)
    @assignment = assignment
    @user = assignment.user
    @meal = assignment.meal.decorate
    @type = assignment.reminder_count == 0 ? :first : :second

    mail(to: @user, subject: default_i18n_subject(
      date: @meal.served_at_short_date
    ))
  end

  def diner_message(message, household)
    @message = message
    @household = household
    @meal = @message.meal.decorate
    mail(to: @household, reply_to: [message.sender_email],
      subject: default_i18n_subject(datetime: @meal.served_at_shorter_date))
  end

  def team_message(message, member)
    @message = message
    @member = member
    @meal = @message.meal.decorate
    mail(to: member, reply_to: [message.sender_email],
      subject: default_i18n_subject(datetime: @meal.served_at_shorter_date))
  end

  protected

  def community
    @meal.community
  end
end
