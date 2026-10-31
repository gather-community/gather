# frozen_string_literal: true

module Admin
  # Filters the admin domains dashboard by whether the domain has Mailman mailing lists.
  class ListLens < Lens::SelectLens
    param_name :lists
    i18n_key "admin.domains.lenses.lists"
    possible_options %i[all with_lists without_lists]
  end
end
