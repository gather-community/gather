module AccountsHelper
  def statement_amount(statement)
    statement.nil? ? "N/A" : link_to(currency_with_cr(statement.total_due), statement)
  end

  def currency_with_cr(amount)
    return "" if amount.blank?
    number_to_currency(amount.abs) << (amount < 0 ? " CR" : "")
  end

  def currency_with_cr_span(amount)
    return "" if amount.blank?
    number_to_currency(amount.abs) <<
      content_tag(:span, amount < 0 ? "CR" : "", class: "cr")
  end


  def late_fee_confirm
    "Are you sure? Fees will be charged to #{@late_fee_count} households. " <<
      if @late_fee_days_ago.nil?
        ""
      else
        "Fees were last applied #{@late_fee_days_ago} days ago."
      end
  end

  def no_user_warning(account)
    if account.household_no_users?
      " ".html_safe << icon_tag("warning", title: "Account household has no associated users")
    else
      ""
    end
  end
end
