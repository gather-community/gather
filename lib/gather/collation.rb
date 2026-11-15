# frozen_string_literal: true

module Gather
  # Sorts text as people expect in the current locale, using Postgres's ICU collations (see
  # Gather::Locales.collation). ApplicationRecord.alpha_order uses it in SQL. For text already in Ruby, whose
  # own sort compares bytes, `sort` and `sort_by` have Postgres do the sorting, so both agree exactly.
  module Collation
    # The current locale's collation, quoted for SQL, e.g. `"sv-x-icu"`.
    def self.quoted_name
      ActiveRecord::Base.connection.quote_column_name(Gather::Locales.collation)
    end

    def self.sort(strings)
      sort_by(strings, &:itself)
    end

    # Like Enumerable#sort_by with a String key. Items with equal keys keep their order.
    def self.sort_by(items, &key)
      items = items.to_a
      return items if items.size < 2
      sql = ActiveRecord::Base.sanitize_sql_array([<<~SQL.squish, items.map { |item| key.call(item).to_s }])
        SELECT i FROM unnest(ARRAY[?]::text[]) WITH ORDINALITY AS t(s, i) ORDER BY s COLLATE #{quoted_name}, i
      SQL
      ActiveRecord::Base.connection.select_values(sql).map { |i| items[i.to_i - 1] }
    end
  end
end
