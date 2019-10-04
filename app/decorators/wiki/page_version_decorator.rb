module Wiki
  class PageVersionDecorator < ApplicationDecorator
    delegate_all

    def updator_name
      updator&.name
    end
  end
end
