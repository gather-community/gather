# frozen_string_literal: true

class CommunitySsoSecrets < ActiveRecord::Migration[6.0]
  def change
    add_column(:communities, :sso_secret, :string)
    add_column(:clusters, :sso_secret, :string)
  end
end
