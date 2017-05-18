# Sends notifications reminding cook to enter menu.
# Sends an early one and then a later one if menu still not entered.
module Meals
  class CookMenuReminderJob < ReminderJob
    def perform
      each_community_at_correct_hour do |community|
        remindable_assignments(community).each do |assignment|
          NotificationMailer.cook_menu_reminder(assignment).deliver_now
          assignment.increment!(:reminder_count)
        end
      end
    end

    private

    def remindable_assignments(community)
      early = Assignment.joins(:meal).
        where(role: "head_cook", reminder_count: 0).
        merge(Meal.without_menu.hosted_by(community).
          served_within_days_from_now(Settings.reminders.lead_times.cook_menu.early))

      late = Assignment.joins(:meal).where(role: "head_cook", reminder_count: 1).
        merge(Meal.without_menu.hosted_by(community).
          served_within_days_from_now(Settings.reminders.lead_times.cook_menu.late))

      (early.to_a + late.to_a).uniq
    end
  end
end
