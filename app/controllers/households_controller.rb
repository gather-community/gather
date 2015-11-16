class HouseholdsController < ApplicationController
  load_and_authorize_resource

  def index
    respond_to do |format|
      format.html do
        @households = @households.includes(:users).by_active_and_name.page(params[:page])
      end
      format.json do
        @households = @households.active.matching(params[:search])
        @households = @households.by_commty_and_name.page(params[:page]).per(20)
        render(json: @households, meta: { more: @households.next_page.present? })
      end
    end
  end

  def show
  end

  def create
    if @household.save
      flash[:success] = "Household created successfully."
      redirect_to households_path
    else
      set_validation_error_notice
      render :new
    end
  end

  def update
    if @household.update_attributes(household_params)
      flash[:success] = "Household updated successfully."
      redirect_to households_path
    else
      set_validation_error_notice
      render :edit
    end
  end

  def destroy
    @household.destroy
    flash[:success] = "Household deleted successfully."
    redirect_to(households_path)
  end

  def accounts
    @accounts = @household.accounts.accessible_by(current_ability, :show).includes(:community).to_a
    @communities = @accounts.map(&:community)

    @account = @accounts.detect{ |a| a.community_id == params[:community].to_i } if params[:community]
    @account ||= @accounts.detect{ |a| a.community == current_user.community } || @accounts.first

    @statements = @account.statements.page(1) if @account
  end

  def activate
    @household.activate!
    flash[:success] = "Household activated successfully."
    redirect_to(households_path)
  end

  def deactivate
    @household.deactivate!
    flash[:success] = "Household deactivated successfully."
    redirect_to(households_path)
  end

  private

  def household_params
    params.require(:household).permit(:name, :community_id, :unit_num, :old_id, :old_name)
  end
end
