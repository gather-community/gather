# frozen_string_literal: true

class SubscriptionsController
  def show
    authorize?()
  end
end
