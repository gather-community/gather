# frozen_string_literal: true

module Meals
  # Calculates a bunch of statistics about the meals system.
  class Report # rubocop:disable Metrics/ClassLength
    attr_accessor :type_map, :community, :range

    SUNDAY = Date.parse("Sunday")

    def initialize(community, range: nil)
      self.community = community
      self.range = range || default_range
    end

    delegate :empty?, to: :by_month

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
        if by_month.present?
          months = by_month.keys - [:all]
          month, max = months.minmax
          while month <= max
            result[month] = by_month[month] || {}
            month >>= 1
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
        all_communities: true
      )
    end

    def by_type
      @by_type ||= types_query.index_by { |row| row["name"] }
    end

    def by_category
      @by_category ||= categories_query.index_by { |row| row["category"] }
    end

    def chart_data # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      @chart_data ||= {
        servings_by_month: [
          by_month_no_totals_or_gaps.each_with_index.map do |k_v, i|
            {x: i, y: k_v[1]["avg_servings"] || 0, l: k_v[0].strftime("%b")}
          end
        ],
        cost_by_month: [
          by_month_no_totals_or_gaps.each_with_index.map do |k_v, i|
            {x: i, y: k_v[1]["avg_max_cost"] || 0, l: k_v[0].strftime("%b")}
          end
        ],
        meals_by_month: [
          by_month_no_totals_or_gaps.each_with_index.map do |k_v, i|
            {x: i, y: k_v[1]["ttl_meals"] || 0, l: k_v[0].strftime("%b")}
          end
        ],
        servings_by_weekday: [
          (by_weekday || {}).each_with_index.map do |k_v, i|
            {x: i, y: k_v[1]["avg_servings"], l: k_v[0].strftime("%a")}
          end
        ],
        cost_by_weekday: [
          (by_weekday || {}).each_with_index.map do |k_v, i|
            {x: i, y: k_v[1]["avg_max_cost"], l: k_v[0].strftime("%a")}
          end
        ],
        meal_types: (by_type || {}).map do |k_v|
          {key: k_v[0], y: k_v[1]["avg_servings"]}
        end,
        community_rep: communities.map do |c|
          by_month ? {key: c.name, y: by_month[:all]["avg_from_#{c.id}"]} : {}
        end
      }
    end

    def cancelled
      Meal
        .hosted_by(community)
        .where("served_at >= ?", range.first)
        .where("served_at < ?", range.last)
        .where(status: "cancelled")
        .count
    end

    private

    def default_range
      # If there are any finalizable meals remaining last month, don't include that month.
      prev_month_range = Time.zone.today.prev_month.beginning_of_month..
        Time.zone.today.prev_month.end_of_month
      range_end = if Meal.hosted_by(community).where(served_at: prev_month_range).finalizable.any?
                    Time.zone.today.prev_month.prev_month.end_of_month
                  else
                    Time.zone.today.prev_month.end_of_month
                  end
      range_end.prev_year.next_month.beginning_of_month..range_end
    end

    def breakout(key_func: nil, totals: false, **sql_options)
      key_func = ->(row) { row["breakout_expr"] } if key_func.nil?

      # Get main rows.
      result = meals_query(**sql_options).index_by(&key_func)

      return {} if result.values.all?(&:empty?)

      # Get totals.
      result[:all] = meals_query(**sql_options.except(:breakout_expr)).first if totals

      result
    end

    def types_query
      type_or_category_query(col_name: "name")
    end

    def categories_query
      type_or_category_query(col_name: "category")
    end

    # rubocop:disable Metrics/MethodLength
    def meals_query(breakout_expr: nil, all_communities: false, ignore_range: false)
      breakout_select = breakout_expr ? "#{breakout_expr} AS breakout_expr," : ""
      breakout_group_order = breakout_expr ? "GROUP BY #{breakout_expr} ORDER BY breakout_expr" : ""
      where_expr, vars = meal_cmty_where_expr(all_communities: all_communities, ignore_range: ignore_range)

      sql = <<-SQL
        SELECT
          #{breakout_select}
          COUNT(*)::integer AS ttl_meals,
          SUM(ingredient_cost + pantry_cost)::real AS ttl_cost,
          AVG(max_meal_costs.max_serving_cost)::real AS avg_max_cost,
          SUM(signup_ttls.ttl_servings)::integer AS ttl_servings,
          AVG(signup_ttls.ttl_servings)::real AS avg_servings,
          #{community_avg_exprs}
        FROM meals
          INNER JOIN communities ON meals.community_id = communities.id
          INNER JOIN (
            SELECT mc.meal_id, ingredient_cost, pantry_cost, MAX(value) AS max_serving_cost
              FROM meal_cost_parts mcp INNER JOIN meal_costs mc ON mcp.cost_id = mc.id
              GROUP BY mc.meal_id, mc.ingredient_cost, mc.pantry_cost
          ) max_meal_costs ON max_meal_costs.meal_id = meals.id
          INNER JOIN (
            SELECT
              ms.meal_id,
              SUM(msp.count) AS ttl_servings,
              #{community_sum_exprs}
            FROM meal_signup_parts msp INNER JOIN meal_signups ms ON msp.signup_id = ms.id
              INNER JOIN households ON households.id = ms.household_id
            GROUP BY ms.meal_id
          ) signup_ttls ON signup_ttls.meal_id = meals.id
        WHERE #{where_expr}
        #{breakout_group_order}
      SQL
      query(sql, *vars).to_a
    end
    # rubocop:enable Metrics/MethodLength

    # rubocop:disable Metrics/MethodLength
    def type_or_category_query(col_name:)
      return [] if empty?

      where_expr, vars = meal_cmty_where_expr
      ttl_meals = by_month[:all]["ttl_meals"]
      avg_servings = by_month[:all]["avg_servings"]

      # Sorting by the minimum associated formula part ID and rank means that types and categories
      # will appear in familiar orders.
      sql = <<-SQL
        SELECT
          meal_types.#{col_name},
          COALESCE(SUM(meal_signup_totals.total::real) / ?, 0) AS avg_servings,
          COALESCE(100 * SUM(meal_signup_totals.total::real) / ? / ?, 0) AS avg_servings_pct
        FROM meal_types
          LEFT OUTER JOIN (
            SELECT meal_signup_parts.type_id, SUM(meal_signup_parts.count) AS total
              FROM meal_signup_parts
                INNER JOIN meal_signups ON meal_signup_parts.signup_id = meal_signups.id
                INNER JOIN meals ON meal_signups.meal_id = meals.id
                INNER JOIN communities ON meals.community_id = communities.id
              WHERE #{where_expr}
              GROUP BY meal_signup_parts.type_id
          ) meal_signup_totals ON meal_signup_totals.type_id = meal_types.id
        WHERE meal_types.id IN (
          SELECT type_id
            FROM meal_formula_parts
              INNER JOIN meal_formulas ON meal_formula_parts.formula_id = meal_formulas.id
              INNER JOIN meals ON meal_formulas.id = meals.formula_id
              INNER JOIN communities ON meals.community_id = communities.id
            WHERE #{where_expr}
        )
        GROUP BY meal_types.#{col_name}
        ORDER BY SUM(meal_signup_totals.total) DESC
      SQL
      query(sql, *[ttl_meals, ttl_meals, avg_servings, vars * 2].flatten).to_a
    end
    # rubocop:enable Metrics/MethodLength

    def meal_cmty_where_expr(ignore_range: false, all_communities: false)
      return @meal_cmty_where_expr if defined?(@meal_cmty_where_expr)

      wheres = ["meals.status = 'finalized'", "communities.cluster_id = ?"]
      wheres << "served_at >= ?" << "served_at < ?" unless ignore_range
      wheres << "meals.community_id = ?" unless all_communities

      vars = [community.cluster_id]
      vars << range.first << range.last unless ignore_range
      vars << community.id unless all_communities

      [wheres.join(" AND "), vars]
    end

    def community_avg_exprs
      communities.map do |c|
        "AVG(ttl_from_#{c.id})::real AS avg_from_#{c.id}, " \
          "(AVG(ttl_from_#{c.id}) * 100 / AVG(signup_ttls.ttl_servings))::real AS avg_from_#{c.id}_pct"
      end.join(",\n")
    end

    def community_sum_exprs
      communities.map do |c|
        expr = "SUM(CASE WHEN households.community_id = #{c.id} THEN msp.count ELSE 0 END)"
        "#{expr} AS ttl_from_#{c.id}"
      end.join(",\n")
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
