class Account
  attr_accessor :household, :preloaded
  attr_writer :last_invoiced_on, :due_last_invoice, :total_new_credits, :total_new_charges
  alias_method :preloaded?, :preloaded

  delegate :name, to: :household, prefix: true

  def self.for_households(households)
    household_ids = households.map(&:id)

    new_amounts = LineItem.select("household_id,
      SUM(CASE WHEN amount < 0 THEN amount ELSE 0 END) AS new_credits,
      SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END) AS new_charges").
      where(household_id: household_ids).
      where(invoice_id: nil).
      group("household_id").index_by(&:household_id)

    invoices = Invoice.select("DISTINCT ON (household_id) household_id, created_at, total_due").
      where(household_id: household_ids).
      order(household_id: :asc, created_at: :desc).index_by(&:household_id)

    households.map do |h|
      account = new(h)
      account.last_invoiced_on = invoices[h.id].try(:[], "created_at").try(:to_date)
      account.due_last_invoice = invoices[h.id].try(:[], "total_due")
      account.total_new_credits = new_amounts[h.id].try(:[], "new_credits").try(:abs) || 0
      account.total_new_charges = new_amounts[h.id].try(:[], "new_charges") || 0
      account.preloaded = true
      account
    end
  end

  def initialize(household)
    self.household = household
  end

  def last_invoiced_on
    return @last_invoiced_on if preloaded?
    @last_invoiced_on ||= last_invoice.try(:created_at).try(:to_date)
  end

  def due_last_invoice
    return @due_last_invoice if preloaded?
    @due_last_invoice ||= last_invoice.try(:total_due)
  end

  def total_new_credits
    return @total_new_credits if preloaded?
    @total_new_credits ||= household.line_items.uninvoiced.credit.sum(:amount).abs
  end

  def total_new_charges
    return @total_new_charges if preloaded?
    @total_new_charges ||= household.line_items.uninvoiced.charge.sum(:amount)
  end

  def outstanding_balance
    @outstanding_balance ||= (due_last_invoice || 0) - total_new_credits
  end

  def current_balance
    @current_balance ||= outstanding_balance + total_new_charges
  end

  private

  def last_invoice
    @last_invoice ||= household.invoices.order(:created_at).last
  end
end