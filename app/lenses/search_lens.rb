class SearchLens < ApplicationLens
  def render
    h.text_field_tag("search", set[:search], placeholder: "Search...", class: "form-control")
  end
end
