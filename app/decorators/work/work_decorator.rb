# frozen_string_literal: true

module Work
  class WorkDecorator < ApplicationDecorator
    def full_community_icon
      h.icon_tag("users", title: t("work/jobs.full_community"))
    end
  end
end
