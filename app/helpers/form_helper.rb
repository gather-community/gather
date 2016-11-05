module FormHelper
  def base_error(f, full_width: false)
    return unless f.object.errors[:base].any?
    col_styles = full_width ? "col-sm-12" : "col-sm-6 col-sm-offset-2"
    # Mimics the way it works for fields
    content_tag(:div, class: "row") do
      content_tag(:div, f.error(:base), class: "has-error base-error #{col_styles}")
    end
  end
end
