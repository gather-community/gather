# frozen_string_literal: true

module Meals
  # Models a single diner within a signup.
  # Will eventually be an AR model once future refactoring is complete.
  class Diner
    attr_accessor :id, :kind

    def initialize(id: nil, kind: nil)
      self.kind = kind
      self.id = id
    end

    # Eventually this method will pull data from the meal formula.
    def kind_options
      Signup::SIGNUP_TYPES.map { |st| [I18n.t("signups.types.#{st}"), st] }
    end

    def new_record?
      id.nil?
    end

    def persisted?
      !new_record?
    end

    def marked_for_destruction?
      false
    end

    def _destroy
      false
    end
  end
end
