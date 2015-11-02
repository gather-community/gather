module AccountsHelper
  def statement_amount(statement)
    statement.nil? ? "N/A" : link_to(number_to_currency(statement.total_due), statement)
  end

  def currency_with_cr(amount)
    number_to_currency(amount.abs) << (amount < 0 ? " CR" : "")
  end
end
