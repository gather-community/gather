# frozen_string_literal: true

class ApplicationSerializer < ActiveModel::Serializer
  protected

  def decorated
    @decorated ||= object.decorate
  end
end
