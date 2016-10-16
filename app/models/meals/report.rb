module Meals
  class Report
    attr_reader :type_map, :community
    SUNDAY = Date.parse("Sunday")

    def initialize(community)
      @community = community
    end

    def range
      @range ||= Date.today.prev_year.beginning_of_month..Date.today.prev_month.end_of_month
    end

    def overview
      return @overview if @overview

      @overview = query("
        SELECT
          meals.host_community_id,
          COUNT(*) AS ttl_meals,
          SUM(signup_ttls.ttl_attendees)::integer AS ttl_attendees,
          SUM(ingredient_cost + pantry_cost)::real AS ttl_cost
        FROM meals
          INNER JOIN meals_costs ON meals.id = meals_costs.meal_id
          LEFT OUTER JOIN (
            SELECT
              signups.meal_id,
              SUM(#{full_signup_col_sum_expr}) AS ttl_attendees
            FROM signups
            GROUP BY signups.meal_id
          ) signup_ttls ON signup_ttls.meal_id = meals.id
        GROUP BY meals.host_community_id
      ").to_a.index_by { |r| r["host_community_id"] }

      # Generate totals.
      @overview[:all] = %w(ttl_meals ttl_attendees ttl_cost).map do |col|
        [col, @overview.sum { |_, v| v[col] || 0 }]
      end.to_h

      @overview[:all]["ttl_meals"] == 0 ? nil : @overview
    end

    def by_month
      @by_month ||= disaggregated(
        by: "TO_CHAR(served_at, 'YYYY-MM-01')",
        key_func: ->(row) { Date.parse(row["disagg_expr"]) }
      )
    end

    def by_weekday
      @by_weekday ||= disaggregated(
        by: "EXTRACT(DOW FROM served_at)::integer",
        key_func: ->(row) { SUNDAY + row["disagg_expr"] }
      )
    end

    private

    def disaggregated(by:, key_func:)
      @by_month = query("
        SELECT
          #{by} AS disagg_expr,
          COUNT(*)::integer AS ttl_meals,
          SUM(ingredient_cost + pantry_cost)::real AS ttl_cost,
          AVG(meals_costs.adult_meat)::real AS avg_adult_cost,
          SUM(signup_ttls.ttl_attendees)::integer AS ttl_attendees,
          AVG(signup_ttls.ttl_attendees)::real AS avg_attendees,
          AVG(signup_ttls.ttl_veg)::real AS avg_veg,
          (AVG(signup_ttls.ttl_veg) / AVG(signup_ttls.ttl_attendees))::real AS avg_veg_pct,
          #{diner_type_avg_exprs}
        FROM meals
          INNER JOIN meals_costs ON meals.id = meals_costs.meal_id
          LEFT OUTER JOIN (
            SELECT
              signups.meal_id,
              SUM(#{full_signup_col_sum_expr}) AS ttl_attendees,
              SUM(#{signup_col_sum_expr(food_types: ['veg'])}) AS ttl_veg,
              #{diner_type_sum_exprs}
            FROM signups
            GROUP BY signups.meal_id
          ) signup_ttls ON signup_ttls.meal_id = meals.id
        WHERE meals.status = 'finalized' AND meals.host_community_id = ?
        GROUP BY #{by}
        ORDER BY disagg_expr
      ", community.id).to_a.index_by(&key_func)

      # Generate totals.
      @by_month[:all] = %w(ttl_meals ttl_attendees ttl_cost).map do |col|
        [col, @by_month.sum { |_, v| v[col] || 0 }]
      end.to_h

      @by_month[:all]["ttl_meals"] == 0 ? nil : @by_month
    end

    def diner_type_avg_exprs
      Signup::DINER_TYPES.map do |dt|
        "AVG(ttl_#{dt})::real AS avg_#{dt}, "\
        "(AVG(ttl_#{dt}) / AVG(signup_ttls.ttl_attendees))::real AS avg_#{dt}_pct"
      end.join(",\n")
    end

    def diner_type_sum_exprs
      Signup::DINER_TYPES.map do |dt|
        expr = signup_col_sum_expr(diner_types: [dt])
        "SUM(#{expr}) AS ttl_#{dt}"
      end.join(",\n")
    end

    def months
      (0...12).to_a.map { |i| range.first >> i }
    end

    def full_signup_col_sum_expr
      @full_signup_col_sum_expr ||= signup_col_sum_expr
    end

    def signup_col_sum_expr(tbl = "signups", prefix: "", diner_types: nil, food_types: nil)
      diner_types ||= Signup::DINER_TYPES
      food_types ||= Signup::FOOD_TYPES
      types = diner_types.map{ |dt| food_types.map{ |ft| "#{prefix}#{dt}_#{ft}" } }.flatten
      types.map { |c| "#{tbl}.#{c}" }.join("+")
    end

    def query(str, *params)
      connection.execute(Meal.send(:sanitize_sql, [str, params])).tap do |result|
        result.type_map = type_map
      end
    end

    def connection
      @connection ||= Meal.connection.tap do |conn|
        @type_map = PG::BasicTypeMapForResults.new(conn.raw_connection)
      end
    end
  end
end
