# frozen_string_literal: true

class AddCountryCodeToCommunity < ActiveRecord::Migration[6.0]
  def change
    add_column :communities, :country_code, :string, limit: 2, default: "us", null: false
  end
end
