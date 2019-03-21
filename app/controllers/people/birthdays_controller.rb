# frozen_string_literal: true

module People
  class BirthdaysController < ApplicationController
    before_action -> { nav_context(:people, :birthdays) }

    decorates_assigned :users

    def index
      authorize(User)
      @users = policy_scope(User).in_community(current_community).by_birthday.active
    end
  end
end
