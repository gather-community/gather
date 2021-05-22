# frozen_string_literal: true

# Maintains rank column
module Rankable
  extend ActiveSupport::Concern

  included do |base|
    before_save :assign_rank
    after_create :fix_ranks
    after_update :fix_ranks
    after_destroy :fix_ranks

    scope :in_rank_scope, ->(n) { where(group_id: n.group_id).where(community_id: n.community_id) }

    define_method :base_rankable_class do
      base
    end
  end

  private

  def assign_rank
    if inactive?
      self.rank = nil
    else
      self.rank ||= (base_rankable_class.in_rank_scope(self).maximum("rank") || 0) + 1
    end
  end

  def fix_ranks
    return unless rank_previously_changed? || group_id_previously_changed? ||
      deactivated_at_previously_changed? || destroyed?

    old_rank = previous_changes["rank"] ? previous_changes["rank"][0] : rank
    old_group_id = previous_changes["group_id"] ? previous_changes["group_id"][0] : group_id

    # If we are moving rank down (increasing the number) within the same scope,
    # we want to lose the tiebreak with any existing ranks when the ranks are being fixed.
    # Since false < true in Postgres sorting, comparing with = will evaluate to true for self,
    # meaning the updated row will lose the tie. In all other cases we want to win the tie.
    tiebreak_op = old_rank && rank && old_group_id == group_id && old_rank < rank ? "=" : "!="

    [old_group_id, group_id].uniq.each { |gid| fix_ranks_for_group_id(gid, tiebreak_op) }
  end

  def fix_ranks_for_group_id(group_id, tiebreak_op)
    example_obj_in_scope = self.class.new(group_id: group_id, community_id: community_id)
    subq = base_rankable_class
      .select(:id, "row_number() OVER (ORDER BY rank, id #{tiebreak_op} #{id}, name) AS rownum")
      .in_rank_scope(example_obj_in_scope)
      .active
      .to_sql
    table = self.class.table_name
    sql = "UPDATE #{table} SET rank = sub.rownum FROM (#{subq}) sub WHERE #{table}.id = sub.id"
    self.class.connection.execute(sql)
  end
end
