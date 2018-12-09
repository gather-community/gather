# frozen_string_literal: true

class AddDoubleSignupsAllowedToJob < ActiveRecord::Migration[5.1]
  def change
    add_column(:work_jobs, :double_signups_allowed, :boolean, default: false)
  end
end
