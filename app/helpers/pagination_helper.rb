# frozen_string_literal: true

# Normally we'd use a decorator but since Kaminari is helper based already we use a helper.
module PaginationHelper
  # Wrap Kaminari's paginate method to include page entries info.
  def gather_paginate(collection)
    if collection.total_pages > 1
      tag.div(class: "pagination-wrapper") do
        paginate(collection) << gather_page_entries_info(collection)
      end
    end
  end

  def gather_page_entries_info(collection)
    return "" if collection[0].nil?

    tag.div(class: "page-entries-info") do
      I18n.t("pagination.page_entries_info.#{collection[0].model_name.i18n_key}",
             first: number_with_delimiter(collection.offset_value + 1),
             last: number_with_delimiter([collection.offset_value + collection.limit_value,
                                          collection.total_count].min),
             total: number_with_delimiter(collection.total_count))
    end
  end
end
