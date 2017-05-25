class StatementsController < ApplicationController
  PER_PAGE = 5

  before_action -> { nav_context(:accounts) }

  def show
    @statement = Billing::Statement.find(params[:id])
    authorize @statement
    @charges = @statement.charges
    @credits = @statement.credits
    @total_charges = @statement.total_charges
    @total_credits = @statement.total_credits
    @community = @statement.community
  end

  def generate
    authorize dummy_statement
    Delayed::Job.enqueue(Billing::StatementJob.new(current_community.id))

    flash[:success] = "Statement generation started. Please try refreshing "\
      "the page in a moment to see updated account statuses."

    if (no_users = Billing::Account.with_activity_but_no_users(current_community)).includes(:household).any?
      flash[:alert] = "The following households have no associated users and thus "\
        "statements were not generated for them: " <<
        (no_users.map { |a| a.household.decorate.name }.join(", ")) <<
        ". Try sending statements again once the households have associated users."
    end

    redirect_to(accounts_path)
  end

  def more
    @account = Billing::Account.find(params[:account_id])
    authorize @account, :show?
    @statements = @account.statements.page(params[:page]).per(StatementsController::PER_PAGE)
    render(partial: "statements/statement_rows")
  end

  protected

  def dummy_statement
    Billing::Statement.new(account: Billing::Account.new(community: current_community))
  end

  # See def'n in ApplicationController for documentation.
  def community_for_route
    case params[:action]
    when "show"
      Billing::Statement.find_by(id: params[:id]).try(:community)
    else
      nil
    end
  end
end
