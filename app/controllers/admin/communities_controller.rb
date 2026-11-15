# frozen_string_literal: true

module Admin
  # Operator pages for communities: the list of every community with activity stats, and each
  # community's details page.
  class CommunitiesController < AdminController
    PER_PAGE = 20

    decorates_assigned :communities, :community

    before_action -> { nav_context(:communities, :communities) }

    def index
      authorize(sample_community)
      prepare_lenses(:search, :"communities/status")
      summarizer = Utils::CommunitySummarizer.new
      scope = policy_scope(Community)

      # Status is computed in Ruby, so filtering and counting by it needs every community. This uses
      # the cheap query; the expensive activity stats are only computed for the current page.
      # The stats cover every community, whatever the lenses say.
      all = summarizer.with_status(scope)
      @stats = Utils::CommunityStats.new(communities: all)
      filtered = all
      if lenses[:search].present?
        ids = ActsAsTenant.without_tenant { scope.matching(lenses[:search].value).pluck(:id) }.to_set
        filtered = filtered.select { |c| ids.include?(c.id) }
      end
      filtered = filtered.select { |c| c.status == lenses[:status].selection } if lenses[:status].active?
      @page = Kaminari.paginate_array(filtered).page(params[:page]).per(PER_PAGE)
      @communities = summarizer.communities(scope, ids: @page.map(&:id))
    end

    def show
      load_community
      authorize(@community, :admin?)
      @community.subscription&.sync!
      @subscription_stripe_error = @community.subscription&.sync_error.present?
    end

    def resync_all
      authorize(sample_community, :index?)
      Subscription::SyncAllJob.perform_later
      redirect_to(admin_communities_path, notice: t("communities.resync_started"))
    end

    def activate
      load_community
      authorize(@community)
      ActsAsTenant.with_tenant(@community.cluster) { @community.activate }
      redirect_to(admin_community_path(@community),
        notice: I18n.t("deactivatable.community.success.activate"))
    end

    def destroy
      load_community
      authorize(@community)
      if params[:confirmation] != @community.slug
        redirect_to(admin_community_path(@community), alert: t("communities.incorrect_slug"))
        return
      end
      CommunityDeletionJob.perform_later(@community.id, current_user.id)
      redirect_to(admin_communities_path, notice: t("communities.being_deleted", name: @community.name))
    end

    private

    def load_community
      ActsAsTenant.without_tenant do
        @community = Community.includes(:cluster, :subscription, :subscription_intent).find(params[:id])
      end
    end

    def sample_community
      Community.new
    end
  end
end
