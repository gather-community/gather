# frozen_string_literal: true

module Admin
  # /admin has no page of its own. It sends the user to the first operator page they can see.
  class HomeController < AdminController
    def show
      authorize(%i[admin home])
      redirect_to(first_permitted_path)
    end

    private

    def first_permitted_path
      if policy(Community.new).index?
        admin_communities_path
      elsif policy(Communities::Signup).index?
        admin_signups_path
      elsif policy(%i[admin domain]).index?
        admin_domains_path
      else
        admin_feature_flags_path
      end
    end
  end
end
