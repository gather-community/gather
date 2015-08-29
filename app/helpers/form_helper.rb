module FormHelper
  def base_error(f)
    return unless f.object.errors[:base].any?
    # Mimics the way it works for fields
    content_tag(:div, f.error(:base), class: "has-error")
  end
end
