# frozen_string_literal: true

module GDrive
  class BrowsePolicy < ApplicationPolicy
    alias_method :item, :record

    def show?
      FeatureFlag.lookup(:gdrive).on?(user)
    end
  end
end
