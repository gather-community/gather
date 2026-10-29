# frozen_string_literal: true

module Admin
  # Adds and removes the selected users on a feature flag. Users can come from any cluster.
  class FeatureFlagUsersController < AdminController
    def create
      authorize(%i[admin feature_flag], :manage_users?)
      flag = find_flag
      user = User.find(params.require(:user_id)).decorate
      flag.feature_flag_users.find_or_create_by!(user: user.object)
      flash[:success] = t("admin.feature_flags.user_added", user: user.full_name, name: flag.name)
      redirect_to(admin_feature_flag_path(flag))
    end

    def destroy
      authorize(%i[admin feature_flag], :manage_users?)
      flag = find_flag
      flag_user = flag.feature_flag_users.find_by!(user_id: params[:id])
      flag_user.destroy!
      flash[:success] = t("admin.feature_flags.user_removed",
        user: flag_user.user.decorate.full_name, name: flag.name)
      redirect_to(admin_feature_flag_path(flag))
    end

    private

    def find_flag
      policy_scope([:admin, FeatureFlag]).find(params[:feature_flag_id])
    end
  end
end
