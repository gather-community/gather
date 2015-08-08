class Meal < ActiveRecord::Base

  DEFAULT_TIME = 18.hours + 15.minutes
  DEFAULT_CAPACITY = 64

  has_one :head_cook, ->{ where(role: "head_cook") }, class_name: "Assignment"
  has_many :asst_cooks, ->{ where(role: "asst_cook") }, class_name: "Assignment"
  has_many :cleaners, ->{ where(role: "cleaner") }, class_name: "Assignment"

  accepts_nested_attributes_for :head_cook, reject_if: :all_blank
  accepts_nested_attributes_for :asst_cooks, reject_if: :all_blank, allow_destroy: true
  accepts_nested_attributes_for :cleaners, reject_if: :all_blank, allow_destroy: true

  def self.new_with_defaults
    meal = new(served_at: default_datetime, capacity: DEFAULT_CAPACITY)
    meal.build_head_cook
    meal.asst_cooks.build
    meal.asst_cooks.build
    meal.cleaners.build
    meal.cleaners.build
    meal
  end

  def self.default_datetime
    (Date.today + 7.days).to_time + DEFAULT_TIME
  end

  def head_cook_id
    assignments.where(role: 'head_cook').first.try(:id)
  end


end
