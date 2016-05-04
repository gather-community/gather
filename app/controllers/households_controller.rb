class HouseholdsController < ApplicationController

  def index
    authorize Household
    @households = policy_scope(Household)
    respond_to do |format|
      format.html do
        @households = @households.includes(:users).by_active_and_name.page(params[:page])
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
    @household = Household.new
    authorize @household
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
      render :new
    end
  end

  def edit
    @household = Household.find(params[:id])
    authorize @household
  end

  def update
    @household = Household.find(params[:id])
    authorize @household
    if @household.update_attributes(permitted_attributes(@household))
      flash[:success] = "Household updated successfully."
      redirect_to households_path
    else
      set_validation_error_notice
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

    @accounts = policy_scope(@household.accounts).includes(:community).to_a
    @communities = @accounts.map(&:community)

    @account = @accounts.detect{ |a| a.community_id == params[:community].to_i } if params[:community]
    @account ||= @accounts.detect{ |a| a.community == current_user.community } || @accounts.first

    @statements = @account.statements.page(1) if @account
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

end
