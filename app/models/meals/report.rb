module Meals
  class Report
    attr_reader :type_map, :community
    SUNDAY = Date.parse("Sunday")

    def initialize(community)
      @community = community
    end

    def range
      return @range if @range

      # If there are any finalizable meals remaining last month, don't include that month.
      prev_month_range = Time.zone.today.prev_month.beginning_of_month..
        Time.zone.today.prev_month.end_of_month
      range_end = if Meal.hosted_by(community).where(served_at: prev_month_range).finalizable.any?
        Time.zone.today.prev_month.prev_month.end_of_month
      else
        Time.zone.today.prev_month.end_of_month
      end

      @range = range_end.prev_year.next_month.beginning_of_month..range_end
    end

    # Returns all diner types that appear in range-constrained results.
    def diner_types
      by_month ? Signup::DINER_TYPES.select { |dt| by_month[:all]["avg_#{dt}"] > 0 } : []
    end

    def overview
      @overview ||= breakout(
        breakout_expr: "meals.community_id::integer",
        all_communities: true,
        ignore_range: true,
        totals: true
      )
    end

    def by_month
      @by_month ||= breakout(
        breakout_expr: "TO_CHAR(served_at, 'YYYY-MM-01')",
        key_func: ->(row) { Date.parse(row["breakout_expr"]) },
        totals: true
      )
    end

    def by_month_no_totals_or_gaps
      @by_month_no_totals_or_gaps ||= ActiveSupport::OrderedHash.new.tap do |result|
        if by_month
          months = by_month.keys - [:all]
          month, max = months.min, months.max
          while month <= max do
            result[month] = by_month[month] || {}
            month = month >> 1
          end
        end
      end
    end

    def by_weekday
      @by_weekday ||= breakout(
        breakout_expr: "EXTRACT(DOW FROM served_at)::integer",
        key_func: ->(row) { SUNDAY + row["breakout_expr"] }
      )
    end

    def by_community
      @by_community ||= breakout(
        breakout_expr: "communities.name",
        all_communities: true,
        include_community: true
      )
    end

    def chart_data
      @chart_data ||= {}.tap do |data|
        data[:diners_by_month] = [
          by_month_no_totals_or_gaps.each_with_index.map do |k_v, i|
            {x: i, y: k_v[1]["avg_diners"] || 0, l: k_v[0].strftime("%b")}
          end
        ]
        data[:cost_by_month] = [
          by_month_no_totals_or_gaps.each_with_index.map do |k_v, i|
            {x: i, y: k_v[1]["avg_adult_cost"] || 0, l: k_v[0].strftime("%b")}
          end
        ]
        data[:meals_by_month] = [
          by_month_no_totals_or_gaps.each_with_index.map do |k_v, i|
            {x: i, y: k_v[1]["ttl_meals"] || 0, l: k_v[0].strftime("%b")}
          end
        ]
        data[:diners_by_weekday] = [
          (by_weekday || {}).each_with_index.map do |k_v, i|
            {x: i, y: k_v[1]["avg_diners"], l: k_v[0].strftime("%a")}
          end
        ]
        data[:cost_by_weekday] = [
          (by_weekday || {}).each_with_index.map do |k_v, i|
            {x: i, y: k_v[1]["avg_adult_cost"], l: k_v[0].strftime("%a")}
          end
        ]
        data[:community_rep] = communities.map do |c|
          by_month ? {key: c.name, y: by_month[:all]["avg_from_#{c.id}"]} : {}
        end
        data[:diner_types] = diner_types.map do |dt|
          by_month ? {key: I18n.t("signups.diner_types.#{dt}", count: 2), y: by_month[:all]["avg_#{dt}"]} : {}
        end
      end
    end

    private

    def breakout(key_func: nil, totals: false, **sql_options)
      key_func = ->(row) { row["breakout_expr"] } if key_func.nil?

      # Get main rows.
      result = meals_query(sql_options).index_by(&key_func)

      # Get totals.
      if totals
        result[:all] = meals_query(sql_options.except(:breakout_expr)).first
      end

      # Return nil if no results.
      result.except(:all).reject { |k, v| v == {} }.empty? ? nil : result
    end

    def meals_query(breakout_expr: nil, all_communities: false, ignore_range: false,
      include_community: false)

      breakout_select = breakout_expr ? "#{breakout_expr} AS breakout_expr," : ""
      breakout_group_order = breakout_expr ? "GROUP BY #{breakout_expr} ORDER BY breakout_expr" : ""

      wheres, vars = [], []

      wheres << "meals.status = 'finalized'"

      unless all_communities
        wheres << "meals.community_id = ?"
        vars << community.id
      end

      unless ignore_range
        wheres << "served_at >= ?" << "served_at < ?"
        vars << range.first << range.last
      end

      community_join = "INNER JOIN communities ON meals.community_id = communities.id"

      # Scope to community cluster
      wheres << "communities.cluster_id = ?"
      vars << community.cluster_id

      query("
        SELECT
          #{breakout_select}
          COUNT(*)::integer AS ttl_meals,
          SUM(ingredient_cost + pantry_cost)::real AS ttl_cost,
          AVG(meal_costs.adult_meat)::real AS avg_adult_cost,
          SUM(signup_ttls.ttl_diners)::integer AS ttl_diners,
          AVG(signup_ttls.ttl_diners)::real AS avg_diners,
          AVG(signup_ttls.ttl_veg)::real AS avg_veg,
          (AVG(signup_ttls.ttl_veg) * 100 / AVG(signup_ttls.ttl_diners))::real AS avg_veg_pct,
          #{diner_type_avg_exprs},
          #{community_avg_exprs}
        FROM meals
          INNER JOIN meal_costs ON meals.id = meal_costs.meal_id
          #{community_join}
          INNER JOIN (
            SELECT
              signups.meal_id,
              SUM(#{full_signup_col_sum_expr}) AS ttl_diners,
              SUM(#{signup_col_sum_expr(food_types: ['veg'])}) AS ttl_veg,
              #{diner_type_sum_exprs},
              #{community_sum_exprs}
            FROM signups
              INNER JOIN households ON households.id = signups.household_id
            GROUP BY signups.meal_id
          ) signup_ttls ON signup_ttls.meal_id = meals.id
        WHERE #{wheres.join(' AND ')}
        #{breakout_group_order}
      ", *vars).to_a
    end

    def diner_type_avg_exprs
      Signup::DINER_TYPES.map do |dt|
        "AVG(ttl_#{dt})::real AS avg_#{dt}, "\
        "(AVG(ttl_#{dt}) * 100 / AVG(signup_ttls.ttl_diners))::real AS avg_#{dt}_pct"
      end.join(",\n")
    end

    def diner_type_sum_exprs
      Signup::DINER_TYPES.map do |dt|
        expr = signup_col_sum_expr(diner_types: [dt])
        "SUM(#{expr}) AS ttl_#{dt}"
      end.join(",\n")
    end

    def community_avg_exprs
      communities.map do |c|
        "AVG(ttl_from_#{c.id})::real AS avg_from_#{c.id}, "\
        "(AVG(ttl_from_#{c.id}) * 100 / AVG(signup_ttls.ttl_diners))::real AS avg_from_#{c.id}_pct"
      end.join(",\n")
    end

    def community_sum_exprs
      communities.map do |c|
        expr = "SUM(CASE WHEN households.community_id = #{c.id} THEN #{full_signup_col_sum_expr} ELSE 0 END)"
        "#{expr} AS ttl_from_#{c.id}"
      end.join(",\n")
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

    def communities
      @communities ||= Community.by_name_with_first(community).to_a
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
