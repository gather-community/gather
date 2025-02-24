# frozen_string_literal: true

class HouseholdDecorator < ApplicationDecorator
  delegate_all

  def greeting
    I18n.t("households.greeting", name: name)
  end

  def name_with_prefix
    suffix = (active? ? "" : " (Inactive)").to_s
    "#{cmty_prefix}#{object.name}#{suffix}"
  end

  def selected_option_tag
    h.tag.option(name_with_prefix, value: id, selected: "selected")
  end

  def emergency_contacts_html
    return "[None]" if emergency_contacts.empty?

    emergency_contacts.map do |contact|
      foreign = contact.country_code != h.current_community.country_code
      phone_format = foreign ? :international : :national
      h.tag.div(class: "emergency-contact") do
        lines = [contact.name_relationship, contact.location]
        lines.concat(contact.phones.map { |p| h.phone_link(p, show_country: foreign, format: phone_format) })
        lines << h.link_to(contact.email, "mailto:#{contact.email}") if contact.email.present?
        h.safe_join(lines, h.tag(:br))
      end
    end.reduce(:<<)
  end

  def pets_html
    return "[None]" if pets.empty?

    pets.map do |pet|
      h.tag.div(class: "pet") do
        lines = []
        lines << "#{pet.name} (#{pet.color} #{pet.species})"
        lines << (h.tag.span("Vet", class: "inner-label") << pet.vet) if pet.vet.present?
        lines << (h.tag.span("Caregivers", class: "inner-label") << pet.caregivers) if pet.caregivers.present?
        if pet.health_issues.present?
          lines << (h.tag.span("Health Issues", class: "inner-label") <<
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
      ActionLink.new(object, :destroy, icon: "trash", path: h.household_path(object), method: :delete,
                                       confirm: {name: name})
    )
  end
end
