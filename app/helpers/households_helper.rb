module HouseholdsHelper
  # Returns a selected option tag if applicable, blank otherwise, for use with select2
  def household_selected_option(household)
    if household.nil?
      ""
    else
      content_tag(:option, household.full_name, value: household.id, selected: "selected")
    end
  end
end
