# frozen_string_literal: true

module Communities
  class StatusLens < Lens::SelectLens
    param_name :status
    i18n_key "communities.community.statuses"

    protected

    def possible_options
      [:all] + Community::STATUSES
    end
  end
end
