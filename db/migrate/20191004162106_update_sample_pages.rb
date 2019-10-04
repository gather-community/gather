# frozen_string_literal: true

class UpdateSamplePages < ActiveRecord::Migration[5.1]
  def up
    ActsAsTenant.without_tenant do
      Wiki::Page.where(slug: "sample").update_all(content: I18n.t("wiki.special_pages.sample.content"))
    end
  end
end
