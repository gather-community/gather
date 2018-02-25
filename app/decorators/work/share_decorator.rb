module Work
  class ShareDecorator < ApplicationDecorator
    delegate_all

    def select_options
      {full: 1.0, half: 0.5, none: 0.0}.map { |n, p| [I18n.t("work/shares.portion_options.#{n}"), p.to_s] }
    end
  end
end
