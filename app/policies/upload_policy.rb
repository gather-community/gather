# frozen_string_literal: true

class UploadPolicy < ApplicationPolicy
  def create?
    active?
  end
end
