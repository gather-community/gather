# frozen_string_literal: true

# Helper methods for using console.
# rubocop:disable Rails/Output
class ConsoleHelper
  include Singleton

  # Sets current tenant
  def tenant(name_or_id, exact: false)
    if name_or_id.is_a?(Integer)
      ActsAsTenant.current_tenant = Cluster.find(name_or_id)
    else
      search = exact ? name_or_id : "%#{name_or_id}%"
      matches = Cluster.where("name ILIKE ?", search)
      if matches.count > 1
        puts("More than one match for #{name_or_id}. Use exact: true or a more specific search.")
        return
      elsif matches.empty?
        puts("No matches found for #{name_or_id}. (exact mode: #{exact ? 'on' : 'off'})")
        return
      end
      ActsAsTenant.current_tenant = matches.first
    end
  end
end
# rubocop:enable Rails/Output

CH = ConsoleHelper.instance
