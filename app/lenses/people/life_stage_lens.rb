# frozen_string_literal: true

module People
  # Filter for adult/child
  class LifeStageLens < Lens::SelectLens
    param_name :lifestage
    i18n_key "simple_form.options.user.life_stage"
    possible_options %i[any adult child]
  end
end
