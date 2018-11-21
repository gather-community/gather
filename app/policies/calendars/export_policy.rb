# frozen_string_literal: true

module Calendars
  class ExportPolicy < ApplicationPolicy
    def index?
      active?
    end

    def show?
      index?
    end

    def reset_token?
      index?
    end
  end
end
