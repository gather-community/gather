# frozen_string_literal: true

module Nav
  # Nav for the operator pages on the apex domain (see AdminController).
  class AdminMenu < Menu
    def main_items
      [
        {
          name: :communities,
          parents: :admin,
          path: communities_permitted? ? h.admin_communities_path : h.admin_signups_path,
          permitted: communities_permitted? || signups_permitted?,
          icon: "home"
        }, {
          name: :domains,
          parents: :admin,
          path: h.admin_domains_path,
          permitted: h.policy(%i[admin domain]).index?,
          icon: "cloud"
        }, {
          name: :flags,
          parents: :admin,
          path: h.admin_feature_flags_path,
          permitted: h.policy(%i[admin feature_flag]).index?,
          icon: "flag"
        }
      ]
    end

    def sub_items(main_item)
      return [] unless main_item == :communities
      [
        {
          name: :communities,
          parents: %i[admin communities],
          path: h.admin_communities_path,
          permitted: communities_permitted?,
          icon: "home"
        }, {
          name: :signups,
          parents: %i[admin communities],
          path: h.admin_signups_path,
          permitted: signups_permitted?,
          icon: "inbox"
        }
      ]
    end

    def personal_items
      [sign_out_item]
    end

    private

    def communities_permitted?
      h.policy(Community.new).index?
    end

    def signups_permitted?
      h.policy(Communities::Signup).index?
    end
  end
end
