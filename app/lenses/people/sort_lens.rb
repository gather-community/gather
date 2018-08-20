# frozen_string_literal: true

module People
  # Sorting the directory
  class SortLens < Lens::SelectLens
    param_name :sort
    i18n_key "simple_form.options.user.sort"
    select_prompt :name
    possible_options %i[unit]
  end
end
