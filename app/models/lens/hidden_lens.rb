# frozen_string_literal: true

module Lens
  # A lens that is not shown in the lens bar.
  class HiddenLens < ::Lens::Lens
    def render
      nil
    end

    # Since the user can't see the lens, there is no point showing an x to clear it.
    def clearable?
      false
    end
  end
end
