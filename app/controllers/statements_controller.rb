# frozen_string_literal: true

class StatementsController < ApplicationController
  PER_PAGE = 5

  before_action -> { nav_context(:accounts) }

  decorates_assigned :statement, :account

  def show
    @statement = Billing::Statement.find(params[:id])
    @account = @statement.account
    @community = @statement.community
    authorize(@statement)
  end

  def generate
    authorize(sample_statement)
    Billing::StatementJob.perform_later(current_community.id)

    flash[:success] = "Statement generation started. Please try refreshing " \
                      "the page in a moment to see updated account statuses."

    with_no_users = Billing::Account.in_community(current_community)
      .includes(:household).with_activity_but_no_users

    if with_no_users.any?
      who = with_no_users.map { |a| a.decorate.household_name }.join(", ")
      flash[:alert] = "The following households have no associated users and thus " \
                      "statements were not generated for them: #{who}. " \
                      "Try sending statements again once the households have associated users."
    end

    redirect_to(accounts_path)
  end

  def more
    @account = Billing::Account.find(params[:account_id])
    authorize(@account, :show?)
    @statements = @account.statements.order(created_at: :desc).page(params[:page]).per(StatementsController::PER_PAGE)
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
