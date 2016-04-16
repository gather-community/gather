module FormHelper
  def base_error(f)
    return unless f.object.errors[:base].any?
    # Mimics the way it works for fields
    content_tag(:div, class: "row") do
      content_tag(:div, f.error(:base), class: "has-error base-error col-sm-6 col-sm-offset-2")
    end
  end
end
