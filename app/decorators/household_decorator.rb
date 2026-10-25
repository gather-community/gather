# frozen_string_literal: true

class HouseholdDecorator < ApplicationDecorator
  delegate_all

  def greeting
    I18n.t("households.greeting", name: name)
  end

  def name_with_prefix
    name = "#{cmty_prefix}#{object.name}"
    active? ? name : I18n.t("common.with_inactive", name: name)
  end

  def selected_option_tag
    h.content_tag(:option, name_with_prefix, value: id, selected: "selected")
  end

  def emergency_contacts_html
    return h.t("common.none_bracketed") if emergency_contacts.empty?
    emergency_contacts.map do |contact|
      foreign = contact.country_code != h.current_community.country_code
      phone_format = foreign ? :international : :national
      h.content_tag(:div, class: "emergency-contact") do
        lines = [h.t("households.emergency_contact", name: contact.name, relationship: contact.relationship),
          contact.location]
        lines.concat(contact.phones.map { |p| h.phone_link(p, show_country: foreign, format: phone_format) })
        lines << h.link_to(contact.email, "mailto:#{contact.email}") if contact.email.present?
        h.safe_join(lines, h.tag(:br))
      end
    end.reduce(:<<)
  end

  def pets_html
    return h.t("common.none_bracketed") if pets.empty?
    pets.map do |pet|
      h.content_tag(:div, class: "pet") do
        lines = []
        lines << h.t("households.pets.summary", name: pet.name, color: pet.color, species: pet.species)
        if pet.vet.present?
          lines << (h.content_tag(:span, h.t("households.pets.vet"), class: "inner-label") << pet.vet)
        end
        if pet.caregivers.present?
          label = h.content_tag(:span, h.t("households.pets.caregivers"), class: "inner-label")
          lines << (label << pet.caregivers)
        end
        if pet.health_issues.present?
          lines << (h.content_tag(:span, h.t("households.pets.health_issues"), class: "inner-label") <<
            h.simple_format(pet.health_issues))
        end
        h.safe_join(lines, h.tag(:br))
      end
    end.reduce(:<<)
  end

  def show_action_link_set
    ActionLinkSet.new(
      ActionLink.new(object, :edit, icon: "pencil", path: h.edit_household_path(object))
    )
  end

  def edit_action_link_set
    ActionLinkSet.new(
      ActionLink.new(object, :deactivate, icon: "times-circle", path: h.deactivate_household_path(object),
        method: :put, confirm: {name: name}),
      ActionLink.new(object, :destroy, icon: "trash", path: "#",
        data: {
          controller: "record-delete",
          "record-delete-url-value": h.household_path(object),
          "record-delete-confirm-token-value": name,
          "record-delete-kind-value": "household",
          action: "record-delete#confirm"
        })
    )
  end
end
