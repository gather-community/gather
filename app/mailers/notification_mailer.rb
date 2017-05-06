class NotificationMailer < ApplicationMailer
  def meal_reminder(user, signup)
    @user = user
    @signup = signup
    @meal = signup.meal

    title = @meal.title ? "#{@meal.title}, " : ""
    subject = "Meal Reminder: #{title}#{@meal.served_at.to_s(:datetime_no_yr)} at #{@meal.location_abbrv}"
    mail(to: @user.email, subject: subject)
  end

  def shift_reminder(assignment)
    @assignment = assignment
    @user = assignment.user
    @meal = assignment.meal
    @role = I18n.t("assignment_roles.#{assignment.role}", count: 1)
    @other_assigns = @meal.assignments.sort.reject{ |a| a.user == @user }
    @date = I18n.l(@assignment.starts_at, format: :date_wkday_no_yr)
    @datetime = I18n.l(@assignment.starts_at, format: :datetime_no_yr)
    @shift_start = I18n.l(@assignment.starts_at, format: :regular_time)
    @shift_end = I18n.l(@assignment.ends_at, format: :regular_time)
    @serve_time = I18n.l(@meal.served_at, format: :regular_time)

    subject = "Job Reminder: You are #{@role} for a meal at #{@datetime} at #{@meal.location_abbrv}"
    mail(to: @user.email, subject: subject)
  end

  def worker_change_notice(initiator, meal, added, removed)
    @initiator = initiator
    @meal = meal
    @added = added
    @removed = removed

    recips = (@meal.assignments + removed).map(&:user).map(&:email)
    recips << @meal.community.settings.meals.admin_email
    recips << @initiator.email

    mail(to: recips.compact.uniq, subject: "Meal Job Assignment Change Notice")
  end

  def cook_menu_reminder(assignment)
    @assignment = assignment
    @user = assignment.user
    @meal = assignment.meal
    @type = assignment.reminder_count == 0 ? :first : :second

    subject = "Menu Reminder: Please post menu for #{@meal.served_at.to_s(:short_date)}"
    mail(to: @user.email, subject: subject)
  end

  private

  def mail(*args)
    raise "meal instance variable must be set" unless @meal
    with_community_subdomain(@meal.community) do
      super(*args)
    end
  end
end
