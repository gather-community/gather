# Sends notifications reminding cook to enter menu.
# Sends an early one and then a later one if menu still not entered.
class CookMenuReminderJob < ReminderJob
  def perform
    return unless correct_hour?

    remindable_assignments.each do |assignment|
      NotificationMailer.cook_menu_reminder(assignment).deliver_now
      assignment.increment!(:reminder_count)
    end
  end

  private

  def remindable_assignments
    early = Assignment.joins(:meal).where(role: "head_cook", reminder_count: 0).
      merge(Meal.without_menu.served_within_days_from_now(Settings.reminder_lead_times.cook_menu.early))

    late = Assignment.joins(:meal).where(role: "head_cook", reminder_count: 1).
      merge(Meal.without_menu.served_within_days_from_now(Settings.reminder_lead_times.cook_menu.late))

    (early.to_a + late.to_a).uniq
  end
end
