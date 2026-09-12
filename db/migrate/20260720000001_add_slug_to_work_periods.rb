# frozen_string_literal: true

class AddSlugToWorkPeriods < ActiveRecord::Migration[8.1]
  # Slugs collide with these sibling route segments, so they must be avoided.
  RESERVED_SLUGS = %w[new edit periods signups jobs report settings].freeze

  def up
    add_column :work_periods, :slug, :string
    backfill_slugs
    change_column_null :work_periods, :slug, false
    add_index :work_periods, %i[community_id slug], unique: true,
      name: "index_work_periods_on_community_id_and_slug"
  end

  def down
    remove_index :work_periods, name: "index_work_periods_on_community_id_and_slug"
    remove_column :work_periods, :slug
  end

  private

  # Assigns a unique-per-community slug to every existing period. Kept self-contained
  # (no dependency on the live model) so the migration is stable over time.
  def backfill_slugs
    klass = Class.new(ActiveRecord::Base) { self.table_name = "work_periods" }
    klass.reset_column_information

    ActsAsTenant.without_tenant do
      klass.order(:id).to_a.group_by(&:community_id).each_value do |periods|
        used = []
        periods.each do |period|
          used << (slug = unique_slug(period.name, used))
          period.update_columns(slug: slug) # rubocop:disable Rails/SkipsModelValidations
        end
      end
    end
  end

  def unique_slug(name, used)
    base = name.to_s.to_slug.normalize.to_s
    base = "period" if base.blank?
    candidate = base
    suffix = 1
    while used.include?(candidate) || RESERVED_SLUGS.include?(candidate)
      suffix += 1
      candidate = "#{base}-#{suffix}"
    end
    candidate
  end
end
