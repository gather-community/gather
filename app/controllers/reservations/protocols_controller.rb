class Reservations::ProtocolsController < ApplicationController
  def index
#    @protocols = Reservations::Protocol.all
    @protocols = policy_scope(Reservations::Protocol)
    authorize @protocols
  end
  def show
    @protocol = Reservations::Protocol.find(params[:id])
    authorize @protocol
  end
  def new
    @protocol = Reservations::Protocol.new
    authorize @protocol
  end
  
end
