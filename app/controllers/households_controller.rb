class HouseholdsController < ApplicationController
  load_and_authorize_resource

  def index
    respond_to do |format|
      format.json do
        @households = @households.matching(params[:search]).sorted.page(params[:page]).per(20)
        render(json: @households, meta: { more: @households.next_page.present? })
      end
    end
  end
end
