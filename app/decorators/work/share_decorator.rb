module Work
  class ShareDecorator < ApplicationDecorator
    delegate_all

    SELECT_OPTIONS = {full: 1.0, three_qtr: 0.75, half: 0.5, one_qtr: 0.25, none: 0.0}

    def select_options
      SELECT_OPTIONS.map { |n, p| [I18n.t("work/shares.portion_options.#{n}"), p.to_s] }
    end
  end
end
