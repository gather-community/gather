# frozen_string_literal: true

# Implements a user select dropdown either as a select2 (hence why we inherit from AssocSelect2)
# or as a simple dropdown (which we achieve by not setting up all the select2 tag attributes)
class UserSelectInput < SimpleForm::Inputs::CollectionSelectInput
  include AssocSelect2able

  def input(wrapper_options)
    # We can't use a plain user select for the specific_community_full_access context if multi community
    # it's dependent on a selection in the form so AJAX is required.
    if current_community.settings.people.plain_user_selects &&
        !(current_cluster.multi_community? && options["context"] == "specific_community_full_access")
      setup_plain_select
    else
      setup_select2
    end
    super
  end

  private

  delegate :current_community, :current_cluster, :current_user, to: :template

  def setup_plain_select
    users = UserSelectScoper.new(scope_name: options[:context], actor: current_user,
                                 community: current_community).resolve
    options[:collection] = users
    options[:include_blank] = options[:allow_clear] == true
    options[:prompt] = options[:allow_clear] == true ? false : "Select User ..."
  end
end
