# frozen_string_literal: true

module Work
  # Combination lens with various options for filtering shifts.
  class ShiftLens < Lens::SelectLens
    REQUESTER_PREFIX = "req"

    param_name :shift
    i18n_key "simple_form.options.work_shift.lens"
    select_prompt :all

    def requester_id
      return unless value =~ /\A#{REQUESTER_PREFIX}(.+)\z/
      Regexp.last_match(1)
    end

    protected

    def option_tags
      main_options << divider << requester_options
    end

    private

    def main_options
      tags_for_options(%i[open me myhh notpre])
    end

    def divider
      h.content_tag(:option, "------", value: "")
    end

    def requester_options
      requesters = Job.requester_options(community: context.current_community)
      id_proc = ->(group) { "#{REQUESTER_PREFIX}#{group.id}" }
      h.options_from_collection_for_select(requesters, id_proc, :name, value)
    end
  end
end
