# frozen_string_literal: true

module Communities
  class SignupStatusLens < Lens::SelectLens
    param_name :status
    i18n_key "simple_form.options.communities_signup.status"
    possible_options %i[all pending approved denied]
  end
end
