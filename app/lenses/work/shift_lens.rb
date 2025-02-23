# frozen_string_literal: true

module Work
  # Combination lens with various options for filtering shifts.
  class ShiftLens < Lens::SelectLens
    REQUESTER_PREFIX = "req"

    param_name :shift
    i18n_key "simple_form.options.work_shift.lens"

    def requester_id
      return unless value =~ /\A#{REQUESTER_PREFIX}(.+)\z/

      Regexp.last_match(1)
    end

    private

    def possible_options
      (main_options << "------").concat(requester_options)
    end

    def main_options
      %i[all open you yourhh notpre]
    end

    def requester_options
      requesters = Job.requester_options(community: context.current_community)
      requesters.map { |r| [r.name, "#{REQUESTER_PREFIX}#{r.id}"] }
    end
  end
end
