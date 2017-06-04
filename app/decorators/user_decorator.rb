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

  def preferred_contact
    return nil if object.preferred_contact.nil?
    I18n.t("simple_form.options.user.preferred_contact.#{object.preferred_contact}")
  end
end
