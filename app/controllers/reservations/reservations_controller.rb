# frozen_string_literal: true

module Reservations
  # Main reservations controller.
  class ReservationsController < ApplicationController
    include Lensable

    decorates_assigned :reservation, :resource, :resources

    before_action -> { nav_context(:reservations, :reservations) }

    def index
      if params[:resource_id]
        @resource = Resource.find(params[:resource_id])

        # We use an unsaved sample reservation to authorize against
        @sample_reservation = Reservation.new(resource: @resource, reserver: current_user)
        authorize @sample_reservation

        # JSON list of reservations for calendar plugin
        if request.xhr?
          raise "Resource required" unless @resource

          @reservations = policy_scope(Reservation)
            .where(resource_id: params[:resource_id])
            .where("starts_at < ? AND ends_at > ?",
              Time.zone.parse(params[:end]), Time.zone.parse(params[:start]))
          render json: @reservations

        # Main reservation pages
        else
          # This will happen in JSON mode.
          # We don't actually return any Reservations here.
          skip_policy_scope

          @rule_set = @sample_reservation.rule_set
          if @rule_set.access_level(current_community) == "read_only"
            flash.now[:notice] = "Only #{@resource.community_name} residents may reserve this resource."
          end

          @other_resources = policy_scope(Resource)
            .where(community_id: @resource.community_id)
            .where("id != ?", @resource.id)
          @other_communities = Community.where("id != ?", @resource.community_id)
          render("calendar")
        end
      else
        prepare_lenses(community: {required: true})
        @community = current_community

        authorize Reservation

        # This will happen in JSON mode.
        # We don't actually return any Reservations here.
        skip_policy_scope

        load_communities_in_cluster
        @resources = policy_scope(Resource).where(community_id: @community.id)
        render("home")
      end
    end

    def show
      @reservation = Reservation.find(params[:id])
      authorize @reservation
      @resource = @reservation.resource
    end

    def new
      @resource = Resource.find_by(id: params[:resource_id])
      raise "Resource not found" unless @resource

      @reservation = Reservation.new_with_defaults(
        resource: @resource,
        reserver: current_user,
        starts_at: params[:start],
        ends_at: params[:end]
      )
      authorize @reservation
      prep_form_vars
    end

    def edit
      @reservation = Reservation.find(params[:id])
      authorize @reservation
      @reservation.guidelines_ok = "1"
      prep_form_vars
    end

    def create
      @reservation = Reservation.new(reserver: current_user)
      set_resource
      @reservation.assign_attributes(reservation_params)
      authorize @reservation
      if @reservation.save
        flash[:success] = "Reservation created successfully."
        redirect_to_reservation_in_context(@reservation)
      else
        prep_form_vars
        set_validation_error_notice(@reservation)
        render :new
      end
    end

    def update
      @reservation = Reservation.find(params[:id])
      authorize @reservation
      return handle_xhr_update if request.xhr?
      if @reservation.update(reservation_params)
        flash[:success] = "Reservation updated successfully."
        redirect_to_reservation_in_context(@reservation)
      else
        prep_form_vars
        set_validation_error_notice(@reservation)
        render :edit
      end
    end

    def destroy
      @reservation = Reservation.find(params[:id])
      authorize @reservation
      @reservation.destroy
      flash[:success] = "Reservation deleted successfully."
      redirect_to(reservations_path(resource_id: @reservation.resource_id))
    end

    protected

    # See def'n in ApplicationController for documentation.
    def community_for_route
      case params[:action]
      when "show"
        Reservation.find_by(id: params[:id]).try(:community)
      when "index"
        current_user.community
      end
    end

    private

    def prep_form_vars
      @resource ||= @reservation.resource
      @kinds = @resource.kinds # May be nil
    end

    def handle_xhr_update
      if @reservation.update(reservation_params.merge(guidelines_ok: "1"))
        head :ok
      else
        render(partial: "update_error_messages", status: :unprocessable_entity)
      end
    end

    # We need to set the resource separately from the other parameters because
    # the resource is what determines the community, and that determines what attributes
    # are permitted to be set. So we don't allow resource_id itself through permitted_attributes.
    def set_resource
      @reservation.resource = Resource.find(params[:reservations_reservation][:resource_id])
    end

    # Pundit built-in helper doesn't work due to namespacing
    def reservation_params
      params.require(:reservations_reservation).permit(policy(@reservation).permitted_attributes)
    end

    def redirect_to_reservation_in_context(reservation)
      redirect_to reservations_path(resource_id: reservation.resource_id,
                                    date: I18n.l(reservation.starts_at, format: :url_date))
    end
  end
end
