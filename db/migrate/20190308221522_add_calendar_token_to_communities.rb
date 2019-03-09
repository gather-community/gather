# frozen_string_literal: true

class AddCalendarTokenToCommunities < ActiveRecord::Migration[5.1]
  def change
    add_column :communities, :calendar_token, :string
    ActsAsTenant.without_tenant do
      Community.find_each do |community|
        community.update_column(:calendar_token, generate_token)
      end
    end
    change_column_null :communities, :calendar_token, false
  end

  private

  def generate_token
    loop do
      token = Devise.friendly_token
      break token unless Community.find_by(calendar_token: token)
    end
  end
end
