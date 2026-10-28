# frozen_string_literal: true

class UserDecorator < ApplicationDecorator
  delegate_all

  def greeting
    I18n.t("users.greeting", name: name)
  end

  def link(highlight: nil, show_cmty_if_foreign: false, show_inactive: false)
    name = full_name(show_inactive: show_inactive)
    if show_cmty_if_foreign && community != h.current_community
      suffix = (show_cmty_if_foreign == :abbrv) ? community_abbrv : community_name
      name = "#{name} (#{suffix})"
    end
    name = h.content_tag(:mark, name) if id == highlight.to_i
    h.link_to(name, h.user_url(object), class: "user-link")
  end

  def full_name(show_inactive: false)
    name = "#{first_name} #{last_name}"
    (active? || !show_inactive) ? name : I18n.t("common.with_inactive", name: name)
  end

  def name_with_inactive
    full_name(show_inactive: true)
  end

  def first_name_with_inactive
    active? ? first_name : I18n.t("common.with_inactive", name: first_name)
  end

  def birthday_formatted
    return nil unless object.birthday?
    l(birthday.date, format: birthday.format)
  end

  def joined_on
    l(object.joined_on)
  end

  def mobile_phone
    phone(:mobile).formatted
  end

  def home_phone
    phone(:home).formatted
  end

  def work_phone
    phone(:work).formatted
  end

  def phone_tags
    phones.map { |p| h.content_tag(:div, p.formatted(kind_abbrv: true), class: "phone") }.reduce(:<<)
  end

  def preferred_contact
    return nil if object.preferred_contact.nil?
    I18n.t("simple_form.options.user.preferred_contact.#{object.preferred_contact}")
  end

  # E.g. "#12" in English, "Nr. 12" in German.
  def formatted_unit_num
    unit_num.nil? ? nil : h.t("households.number", number: unit_num_and_suffix)
  end

  def unit_link
    unit_num.nil? ? nil : h.link_to(formatted_unit_num, household)
  end

  def first_phone_link
    no_phones? ? nil : h.phone_link(phones.first, kind_abbrv: true)
  end

  def unit_and_phone
    [unit_link, first_phone_link].compact.reduce(&sep(" &bull; "))
  end

  def tr_classes
    active? ? "" : "inactive"
  end

  def email_link
    email.blank? ? "" : h.link_to(email, "mailto:#{email}", class: long_email_class)
  end

  def long_email_class
    (email.size > 25) ? "long-email" : ""
  end

  def household_hint
    chunks = []

    unless user.persisted?
      chunks << safe_str
      chunks[-1] << h.t("users.household_hint.choose_html",
        link: h.link_to(h.t("users.household_hint.create_link"), h.new_household_path))
    end

    if user.child?
      chunks << h.t("users.household_hint.child_note")
    end

    h.safe_join(chunks, " ")
  end

  def preferred_contact_icon
    case object.preferred_contact
    when "email" then "envelope"
    when "text" then "comment"
    when "phone" then "phone"
    end
  end

  def preferred_contact_tooltip
    h.t("users.preferred_contact_tooltip", method: preferred_contact)
  end

  def photo_if_permitted(format)
    image = photo_variant(format, suppress: !h.policy(object).show_photo?)
    h.image_tag(image, class: "photo", alt: h.t("users.photo_of", name: full_name))
  end

  def photo_variant(format, suppress: false)
    return "missing/users/#{format}.png" if suppress || !photo.attached? || !photo.variable?
    case format
    when :thumb then photo.variant(resize_to_fill: [150, 150])
    when :medium then photo.variant(resize_to_fill: [300, 300])
    else raise "Unknown photo format #{format}"
    end
  end

  def show_action_link_set
    ActionLinkSet.new(
      ActionLink.new(object, :update_info, icon: "pencil", path: h.edit_user_path(object)),
      ActionLink.new(object, :update_photo, icon: "camera", path: h.edit_user_path(object)),
      ActionLink.new(object, :impersonate, icon: "user-circle", path: h.impersonate_user_path(object),
        method: :post),
      ActionLink.new(object, :invite,
        icon: "life-ring",
        method: :post,
        path: h.people_sign_in_invitations_path(object, "to_invite[]": id),
        confirm: {name: name},
        permitted: People::SignInInvitationsPolicy.new(h.current_user, object).create?)
    )
  end

  def edit_action_link_set
    ActionLinkSet.new(
      ActionLink.new(object, :deactivate, icon: "times-circle", path: h.deactivate_user_path(object),
        method: :put, confirm: {name: name}),
      ActionLink.new(object, :destroy, icon: "trash", path: "#",
        label_symbol: ((object == h.current_user) ? :delete_self : :destroy),
        data: {
          controller: "record-delete",
          "record-delete-url-value": h.user_path(object),
          "record-delete-confirm-token-value": "#{object.first_name} #{object.last_name}",
          "record-delete-kind-value": "user",
          action: "record-delete#confirm"
        })
    )
  end
end
