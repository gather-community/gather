# frozen_string_literal: true

module Calendars
  class ExportDecorator < ApplicationDecorator
    attr_accessor :community, :user

    def initialize(community, user)
      self.community = community
      self.user = user
    end
  end
end
