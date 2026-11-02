# frozen_string_literal: true

# The currency a community's money is shown in, backfilled from its country. Every ISO country has a
# currency in the countries gem, so the backfill raises rather than guessing if one can't be found.
class AddCurrencyToCommunities < ActiveRecord::Migration[8.1]
  def up
    add_column :communities, :currency, :string, limit: 3

    execute("SELECT id, country_code FROM communities").each do |row|
      currency = ISO3166::Country.new(row["country_code"])&.currency_code&.downcase
      raise "No currency for community #{row["id"]} (country #{row["country_code"].inspect})" if currency.nil?
      execute("UPDATE communities SET currency = #{connection.quote(currency)} WHERE id = #{row["id"]}")
    end

    change_column_null :communities, :currency, false
    add_check_constraint :communities, "currency ~ '^[a-z]{3}$'", name: "currency_format"
  end

  def down
    remove_column :communities, :currency
  end
end
