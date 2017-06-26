class MealMailer < ApplicationMailer
  # TODO: Refactor to accept a household instead of a user
  # It should be up to the mailer system, not the job system to figure out how to send mail to a household,
  # and whether users have opted out of a given type of mail.
  # Mails to households should also be addressed to all the household users, not to each user separately.
  # This is how it's done in the accounts mailer.
  def meal_reminder(user, signup)
    @user = user
    @signup = signup
    @meal = signup.meal.decorate

    mail(to: @user.email, subject: default_i18n_subject(
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

    mail(to: @user.email, subject: default_i18n_subject(
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

    recips = (@meal.assignments + removed).map(&:user).map(&:email)
    recips << @meal.community.settings.meals.admin_email
    recips << @initiator.email

    mail(to: recips.compact.uniq)
  end

  def cook_menu_reminder(assignment)
    @assignment = assignment
    @user = assignment.user
    @meal = assignment.meal.decorate
    @type = assignment.reminder_count == 0 ? :first : :second

    mail(to: @user.email, subject: default_i18n_subject(
      date: @meal.served_at_short_date
    ))
  end

  def diner_message(message, household)
    @message = message
    @household = household
    @meal = @message.meal.decorate

    mail(to: household_emails, subject: default_i18n_subject(
      datetime: @meal.served_at_datetime_no_yr
    ))
  end

  def team_message(message, member)
    @message = message
    @member = member
    @meal = @message.meal.decorate

    mail(to: member.email, subject: default_i18n_subject(
      datetime: @meal.served_at_datetime_no_yr
    ))
  end

  private

  def mail(*args)
    raise "meal instance variable must be set" unless @meal
    with_community_subdomain(@meal.community) do
      super.tap { |x| puts x.body }
    end
  end
end
