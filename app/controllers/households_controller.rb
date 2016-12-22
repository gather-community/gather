class HouseholdsController < ApplicationController
  include Lensable

  before_action -> { nav_context(:people) }, except: :accounts

  def index
    authorize Household
    @households = policy_scope(Household)
    respond_to do |format|
      format.html do
        nav_context(:people, :households)
        prepare_lens(:community, :search)
        @households = @households.includes(:users)
        if lens[:search].present?
          @households = @households.matching(lens[:search])
        end
        if lens[:community].present?
          @households = @households.in_community(Community.find_by_abbrv(lens[:community]))
        end
        @households = @households.by_active_and_name.page(params[:page])
      end
      format.json do
        @households = @households.active.matching(params[:search])
        @households = @households.by_commty_and_name.page(params[:page]).per(20)
        render(json: @households, meta: { more: @households.next_page.present? }, root: "results")
      end
    end
  end

  def show
    @household = Household.find(params[:id])
    authorize @household
  end

  def new
    @household = Household.new(community: current_community)
    authorize @household
    prepare_household
  end

  def create
    @household = Household.new
    @household.assign_attributes(permitted_attributes(@household))
    authorize @household
    if @household.save
      flash[:success] = "Household created successfully."
      redirect_to households_path
    else
      set_validation_error_notice
      prepare_household
      render :new
    end
  end

  def edit
    @household = Household.find(params[:id])
    authorize @household
    prepare_household
  end

  def update
    @household = Household.find(params[:id])
    authorize @household
    if @household.update_attributes(permitted_attributes(@household))
      flash[:success] = "Household updated successfully."
      redirect_to households_path
    else
      set_validation_error_notice
      prepare_household
      render :edit
    end
  end

  def destroy
    @household = Household.find(params[:id])
    authorize @household
    @household.destroy
    flash[:success] = "Household deleted successfully."
    redirect_to(households_path)
  end

  def accounts
    @household = Household.find(params[:id])
    authorize @household

    @community = params[:community] ? Community.find(params[:community]) : current_user.community

    @accounts = policy_scope(@household.accounts).includes(:community).to_a
    @communities = @accounts.map(&:community)

    @account = @accounts.detect{ |a| a.community_id == @community.id } || @accounts.first

    @statements = @account.statements.page(1).per(StatementsController::PER_PAGE) if @account
    @last_statement = @account.last_statement
  end

  def activate
    @household = Household.find(params[:id])
    authorize @household
    @household.activate!
    flash[:success] = "Household activated successfully."
    redirect_to(households_path)
  end

  def deactivate
    @household = Household.find(params[:id])
    authorize @household
    @household.deactivate!
    flash[:success] = "Household deactivated successfully."
    redirect_to(households_path)
  end

  private

  def prepare_household
    @household.vehicles.build if @household.vehicles.empty?
  end
end
