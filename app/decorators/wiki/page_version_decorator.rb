# frozen_string_literal: true

module Wiki
  class PageVersionDecorator < ApplicationDecorator
    delegate_all

    def updater_name
      updater&.name
    end
  end
end
