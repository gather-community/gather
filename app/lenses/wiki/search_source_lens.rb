# frozen_string_literal: true

module Wiki
  # Filters search results by source: all, wiki, or drive.
  class SearchSourceLens < Lens::SelectLens
    param_name :source
    i18n_key "simple_form.options.wiki_search.source"
    possible_options %i[all wiki drive]
  end
end
