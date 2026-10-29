# frozen_string_literal: true

module Admin
  # Operator dashboard for feature flags: switch each flag off, on for selected users, or on for
  # everyone, and manage the selected users. Flags are global, and users can come from any cluster.
  class FeatureFlagsController < AdminController
    USER_SEARCH_MIN_LENGTH = 2
    USER_SEARCH_LIMIT = 10

    def index
      authorize(%i[admin feature_flag])
      @flags = policy_scope([:admin, FeatureFlag]).by_name
      @user_counts = FeatureFlagUser.where(feature_flag: @flags).group(:feature_flag_id).count
    end

    def show
      authorize(%i[admin feature_flag])
      @flag = find_flag
      @users = @flag.users.including_communities.by_name.decorate
    end

    def new
      authorize(%i[admin feature_flag])
      @form = FeatureFlagForm.new
    end

    def edit
      authorize(%i[admin feature_flag])
      @form = FeatureFlagForm.new(flag: find_flag)
    end

    def create
      authorize(%i[admin feature_flag])
      @form = FeatureFlagForm.new(params: params.require(:feature_flag))
      if @form.save
        flash[:success] = t("admin.feature_flags.created", name: @form.name)
        redirect_to(admin_feature_flag_path(@form.flag))
      else
        render(:new, status: :unprocessable_entity)
      end
    end

    def update
      authorize(%i[admin feature_flag])
      @form = FeatureFlagForm.new(flag: find_flag, params: params.require(:feature_flag),
        permitted: policy(%i[admin feature_flag]).permitted_attributes_for_update)
      if @form.save
        flash[:success] = t("admin.feature_flags.mode_changed.#{@form.mode}", name: @form.name)
        redirect_to(admin_feature_flag_path(@form.flag))
      else
        render(:edit, status: :unprocessable_entity)
      end
    end

    def destroy
      authorize(%i[admin feature_flag])
      flag = find_flag
      flag.destroy!
      flash[:success] = t("admin.feature_flags.deleted", name: flag.name)
      redirect_to(admin_feature_flags_path)
    end

    # JSON for the add-user search box. Matches active users in any cluster by name or email,
    # leaving out users already on the flag.
    def user_search
      authorize(%i[admin feature_flag], :manage_users?)
      flag = find_flag
      query = params[:q].to_s.strip
      users = if query.size < USER_SEARCH_MIN_LENGTH
        User.none
      else
        pattern = "%#{User.sanitize_sql_like(query)}%"
        User.active.non_placeholder
          .where("(users.first_name || ' ' || users.last_name) ILIKE :p OR users.email ILIKE :p", p: pattern)
          .where.not(id: flag.feature_flag_users.select(:user_id))
          .including_communities.by_name.limit(USER_SEARCH_LIMIT)
      end
      render(json: {results: users.decorate.map { |u| user_search_result(u) }})
    end

    private

    def find_flag
      policy_scope([:admin, FeatureFlag]).find(params[:id])
    end

    def user_search_result(user)
      {id: user.id, name: user.full_name, email: user.email, community: user.community.name}
    end
  end
end
