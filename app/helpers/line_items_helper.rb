module LineItemsHelper
  def line_item_code_options
    LineItem::MANUALLY_ADDABLE_TYPES.map{ |t| [I18n.t("line_item_codes.#{t.code}"), t.code] }
  end
end
