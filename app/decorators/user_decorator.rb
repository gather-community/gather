class UserDecorator < ApplicationDecorator
  delegate_all

  def birthdate
    return nil if object.birthdate.nil?
    I18n.l(object.birthdate, format: :full)
  end

  def joined_on
    l(object.joined_on, format: :full)
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

  def unit_num_with_hash
    unit_num.nil? ? nil : "##{unit_num}"
  end

  def unit_link
    unit_num.nil? ? nil : h.link_to("##{unit_num}", household)
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
    email.size > 25 ? "long-email" : ""
  end
end
