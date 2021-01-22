# frozen_string_literal: true

module Groups
  # Sorting the list of gruops
  class SortLens < Lens::SelectLens
    param_name :sort
    i18n_key "simple_form.options.groups_group.sort"
    possible_options %i[name type]

    def by_type?
      value == "type"
    end
  end
end
