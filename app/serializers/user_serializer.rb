# frozen_string_literal: true

class UserSerializer < ApplicationSerializer
  attributes :id, :name

  def name
    object.full_name(show_inactive: !instance_options[:hide_inactive_in_name])
  end
end
