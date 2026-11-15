# frozen_string_literal: true

# Makes every decimal attribute (model columns and form-model attributes alike) accept numbers typed in the
# current locale's style, so a French user's "12,50" is 12.5 rather than Ruby's 12. See
# Gather::LocalizedNumber for the rules. Values that aren't Strings, e.g. BigDecimals read from the
# database, are untouched.
module LocalizedDecimalCasting
  private

  def cast_value(value)
    super(Gather::LocalizedNumber.normalize(value))
  end
end

ActiveModel::Type::Decimal.prepend(LocalizedDecimalCasting)
