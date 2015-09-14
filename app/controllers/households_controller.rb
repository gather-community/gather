class HouseholdsController < ApplicationController
  load_and_authorize_resource

  def index
    respond_to do |format|
      format.html do
        @households = @households.includes(:users).by_name.page(params[:page])
      end
      format.json do
        @households = @households.matching(params[:search])
        @households = @households.by_commty_and_name.page(params[:page]).per(20)
        render(json: @households, meta: { more: @households.next_page.present? })
      end
    end
  end
end
