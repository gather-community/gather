# frozen_string_literal: true

class StatementsController < ApplicationController
  PER_PAGE = 5

  before_action -> { nav_context(:accounts) }

  decorates_assigned :statement

  def show
    @statement = Billing::Statement.find(params[:id]).decorate
    authorize(@statement)
  end

  def generate
    authorize(sample_statement)
    Delayed::Job.enqueue(Billing::StatementJob.new(current_community.id))

    flash[:success] = "Statement generation started. Please try refreshing "\
      "the page in a moment to see updated account statuses."

    with_no_users = Billing::Account.includes(:household).with_activity_but_no_users(current_community)

    if with_no_users.any?
      flash[:alert] = "The following households have no associated users and thus "\
        "statements were not generated for them: " <<
        with_no_users.map { |a| a.decorate.household_name }.join(", ") <<
        ". Try sending statements again once the households have associated users."
    end

    redirect_to(accounts_path)
  end

  def more
    @account = Billing::Account.find(params[:account_id])
    authorize(@account, :show?)
    @statements = @account.statements.page(params[:page]).per(StatementsController::PER_PAGE)
    render(partial: "statements/statement_rows")
  end

  protected

  def sample_statement
    Billing::Statement.new(account: Billing::Account.new(community: current_community))
  end

  # See def'n in ApplicationController for documentation.
  def community_for_route
    case params[:action]
    when "show"
      Billing::Statement.find_by(id: params[:id]).try(:community)
    end
  end
end
