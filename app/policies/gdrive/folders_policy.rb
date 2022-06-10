# frozen_string_literal: true

module GDrive
  class FoldersPolicy < ApplicationPolicy
    alias folder record

    def show?
      FeatureFlag.lookup(:gdrive).on?(user)
    end
  end
end
