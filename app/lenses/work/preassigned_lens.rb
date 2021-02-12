# frozen_string_literal: true

module Work
  # For filtering pre or non-pre assigned.
  class PreassignedLens < Lens::SelectLens
    param_name :pre
    i18n_key "simple_form.options.work_job.preassigned"
    possible_options %i[any y n]

    def yes?
      y?
    end

    def no?
      n?
    end
  end
end
