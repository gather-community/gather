# frozen_string_literal: true

module GDrive
  class BrowsePolicy < ApplicationPolicy
    alias item record

    def index?
      true
    end
  end
end
