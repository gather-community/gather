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
      @overview ||= breakout(
        breakout_expr: "meals.host_community_id::integer",
        all_communities: true,
        ignore_range: true
      )
    end

    def by_month
      @by_month ||= breakout(
        breakout_expr: "TO_CHAR(served_at, 'YYYY-MM-01')",
        key: ->(row) { Date.parse(row["breakout_expr"]) }
      )
    end

    def by_weekday
      @by_weekday ||= breakout(
        breakout_expr: "EXTRACT(DOW FROM served_at)::integer",
        key: ->(row) { SUNDAY + row["breakout_expr"] }
      )
    end

    private

    def breakout(key: nil, **sql_options)
      key = ->(row) { row["breakout_expr"] } if key.nil?

      # Get main rows.
      result = meals_query(sql_options).index_by(&key)

      # Get totals.
      result[:all] = meals_query(sql_options.except(:breakout_expr)).first

      # Return nil if no results.
      result[:all]["ttl_meals"] == 0 ? nil : result
    end

    def meals_query(breakout_expr: nil, all_communities: false, ignore_range: false)
      breakout_select = breakout_expr ? "#{breakout_expr} AS breakout_expr," : ""
      breakout_group_order = breakout_expr ? "GROUP BY #{breakout_expr} ORDER BY breakout_expr" : ""

      wheres, vars = [], []

      wheres << "meals.status = 'finalized'"

      unless all_communities
        wheres << "meals.host_community_id = ?"
        vars << community.id
      end

      unless ignore_range
        wheres << "served_at >= ?" << "served_at < ?"
        vars << range.first << range.last
      end

      query("
        SELECT
          #{breakout_select}
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
        WHERE #{wheres.join(' AND ')}
        #{breakout_group_order}
      ", *vars).to_a
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

    def query(str, *vars)
      connection.execute(Meal.send(:sanitize_sql, [str, *vars])).tap do |result|
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
