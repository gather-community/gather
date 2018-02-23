module Work
  class ShareDecorator < ApplicationDecorator
    delegate_all

    def self.select_options
      {full: 1, half: 0.5, none: 0}.map { |n, p| [I18n.t("work/shifts.portion_options.#{n}"), p] }
    end
  end
end
