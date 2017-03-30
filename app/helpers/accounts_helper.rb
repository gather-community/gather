module AccountsHelper
  def statement_amount(statement)
    statement.nil? ? "N/A" : link_to(currency_with_cr(statement.total_due), statement_path(statement))
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

  def link_to_currency_if_nonzero(amt, target)
    if amt.abs > 0.01
      link_to(number_to_currency(amt), target)
    else
      number_to_currency(amt)
    end
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

  def statement_confirm_msg
    msg = "Are you sure? Statements will be sent out to "\
      "#{@active_accounts - @no_user_accounts - @recent_stmt_accounts} households."
    if @no_user_accounts > 0
      msg << "\n\n" << t(".no_users", count: @no_user_accounts)
    end
    if @recent_stmt_accounts > 0
      msg << "\n\n" << t(".recent_statements", count: @recent_stmt_accounts)
    end
    msg
  end

  def credit_limit(account)
    if account.credit_limit
      num = number_to_currency(account.credit_limit)
      account.credit_exceeded? ? content_tag(:span, num, class: "exceeded") : num
    else
      "None"
    end
  end

  def payment_instructions
    if instr = @community.settings.billing.payment_instructions
      content_tag(:h4, "How to Pay", class: "inner") << safe_render_markdown(instr)
    end
  end
end
