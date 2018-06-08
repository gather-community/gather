# frozen_string_literal: true

module Work
  class Reminder < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :job, class_name: "Work::Job", inverse_of: :reminders
  end
end
