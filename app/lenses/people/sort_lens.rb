# frozen_string_literal: true

module People
  # Sorting the directory
  class SortLens < Lens::SelectLens
    param_name :sort
    i18n_key "simple_form.options.user.sort"
    possible_options %i[name unit]
  end
end
