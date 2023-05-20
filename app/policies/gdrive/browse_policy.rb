# frozen_string_literal: true

module GDrive
  class BrowsePolicy < ApplicationPolicy
    alias_method :item, :record

    def index?
      true
    end
  end
end
