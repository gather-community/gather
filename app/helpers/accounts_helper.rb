module AccountsHelper
  def statement_amount(statement)
    statement.nil? ? "N/A" : link_to(number_to_currency(statement.total_due), statement)
  end

  def currency_with_cr(amount)
    number_to_currency(amount.abs) << (amount < 0 ? " CR" : "")
  end

  def late_fee_confirm
    "Are you sure? Fees will be charged to #{@late_fee_count} households. " <<
      if @late_fee_days_ago.nil?
        ""
      else
        "Fees were last applied #{@late_fee_days_ago} days ago."
      end
  end
end
