# frozen_string_literal: true

module CustomFields
  module Fields
    class StringField < TextualField
      def type
        :string
      end
    end
  end
end
