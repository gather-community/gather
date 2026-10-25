# frozen_string_literal: true

class CommunityDecorator < ApplicationDecorator
  delegate_all

  def admin_action_link_set
    ActionLinkSet.new(
      ActionLink.new(object, :visit, icon: "external-link", path: h.url_in_community(object),
        permitted: true, html: {target: "_blank", rel: "noopener"}),
      ActionLink.new(object, :destroy, icon: "trash", path: "#",
        btn_class: :danger,
        data: {
          controller: "record-delete",
          "record-delete-url-value": h.community_path(object),
          "record-delete-confirm-token-value": object.slug,
          "record-delete-kind-value": "community",
          action: "record-delete#confirm"
        })
    )
  end

  def country_name
    country = ISO3166::Country[object.country_code]
    country&.translations&.[](I18n.locale.to_s) || country&.name || object.country_code
  end
end
