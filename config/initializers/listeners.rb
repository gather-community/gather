# frozen_string_literal: true

Rails.application.config.after_initialize do
  Work::JobReminder.subscribe(Work::JobReminderMaintainer.instance)
  Work::Job.subscribe(Work::JobReminderMaintainer.instance)

  Meals::RoleReminder.subscribe(Meals::RoleReminderMaintainer.instance)
  Meals::Formula.subscribe(Meals::RoleReminderMaintainer.instance)
  Meals::Meal.subscribe(Meals::RoleReminderMaintainer.instance)
  Meals::Role.subscribe(Meals::RoleReminderMaintainer.instance)

  User.subscribe(Work::ShiftIndexUpdater.instance)
  Groups::Group.subscribe(Work::ShiftIndexUpdater.instance)
  Work::Job.subscribe(Work::ShiftIndexUpdater.instance)
end
