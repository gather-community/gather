# frozen_string_literal: true

module Meals
  # Models a single diner within a signup.
  # Will eventually be an AR model once future refactoring is complete.
  class Diner
    attr_accessor :kind

    def initialize(kind: nil)
      self.kind = kind
    end

    # Eventually this method will pull data from the meal formula.
    def kind_options
      Signup::SIGNUP_TYPES.map { |st| [I18n.t("signups.types.#{st}"), st] }
    end

    def id
      nil
    end

    def new_record?
      true
    end

    def marked_for_destruction?
      false
    end

    def _destroy
      false
    end

    def persisted?
      false
    end
  end
end
