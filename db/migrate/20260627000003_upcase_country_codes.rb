# frozen_string_literal: true

# Standardize country_code on ISO 3166-1 alpha-2 uppercase. Prod had mixed-case values,
# which broke case-sensitive lookups (e.g. Messaging::Account currency selection).
class UpcaseCountryCodes < ActiveRecord::Migration[8.1]
  def up
    execute("UPDATE communities SET country_code = UPPER(country_code) WHERE country_code IS NOT NULL")
    execute("UPDATE community_signups SET country_code = UPPER(country_code) WHERE country_code IS NOT NULL")
  end

  def down
    # Irreversible: the original casing is not recoverable.
  end
end
