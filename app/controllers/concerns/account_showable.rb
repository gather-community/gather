# Methods common to controllers that can render the account details partial
module AccountShowable
  extend ActiveSupport::Concern

  def prep_account_vars
    @statements = @account.statements.page(params[:page] || 1).per(StatementsController::PER_PAGE)
    @last_statement = @account.last_statement
    @has_activity = @account.transactions.any?
  end
end
