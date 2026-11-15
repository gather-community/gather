# frozen_string_literal: true

module AccountsHelper
  def statement_amount(statement)
    return t("accounts.not_applicable") if statement.nil?
    link_to(currency_with_cr(statement.total_due), statement_path(statement))
  end

  def currency_with_cr(amount)
    return "" if amount.blank?
    return format_money(amount) unless amount.negative?
    t("accounts.credit_amount_html", amount: format_money(-amount))
  end

  def currency_with_cr_span(amount)
    return "" if amount.blank?
    format_money(amount.abs) <<
      content_tag(:span, amount.negative? ? t("accounts.credit_abbr") : "", class: "cr")
  end

  def link_to_currency_if_nonzero(amt, target)
    if amt.abs > 0.01
      link_to(format_money(amt), target)
    else
      format_money(amt)
    end
  end

  def late_fee_confirm
    if @late_fee_days_ago.nil?
      t("accounts.late_fee_confirm", count: @late_fee_count)
    else
      t("accounts.late_fee_confirm_with_days", count: @late_fee_count, days: @late_fee_days_ago)
    end
  end

  def no_user_warning(account)
    if account.household_no_users?
      " ".html_safe << icon_tag("warning", title: t("accounts.no_users_warning"))
    else
      ""
    end
  end

  def statement_confirm_msg
    msg = +t("accounts.statement_confirm", count: @statement_accounts)
    msg << "\n\n" << t("accounts.index.no_users", count: @no_user_accounts) if @no_user_accounts > 0
    msg << "\n\n" << t("accounts.index.recent_statements", count: @recent_stmt_accounts) if @recent_stmt_accounts > 0
    msg
  end
end
