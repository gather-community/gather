# frozen_string_literal: true

module Groups
  # Sorting the list of gruops
  class SortLens < Lens::SelectLens
    param_name :sort
    i18n_key "simple_form.options.groups_group.sort"
    select_prompt :name
    possible_options %i[type]

    def by_type?
      value == "type"
    end
  end
end
