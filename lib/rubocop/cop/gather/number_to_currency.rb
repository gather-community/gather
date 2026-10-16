# frozen_string_literal: true

module RuboCop
  module Cop
    module Gather
      # Flags number_to_currency, which takes the currency from the locale, so a Canadian community viewed
      # in French would see euros. Use format_money, which takes the currency from the community.
      #
      # @example
      #   # bad
      #   number_to_currency(meal.cost)
      #
      #   # good
      #   format_money(meal.cost)
      class NumberToCurrency < Base
        MSG = "Use format_money, which takes the currency from the community rather than the locale."
        RESTRICT_ON_SEND = %i[number_to_currency].freeze

        def on_send(node)
          add_offense(node.loc.selector)
        end
      end
    end
  end
end
