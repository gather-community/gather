# frozen_string_literal: true

class CreateBillingTemplateMemberTypes < ActiveRecord::Migration[6.0]
  def change
    create_table :billing_template_member_types do |t|
      t.references :cluster, foreign_key: true, index: true, null: false
      t.references :template, foreign_key: {to_table: :billing_templates}, index: true, null: false
      t.references :member_type, foreign_key: {to_table: :people_member_types}, index: true, null: false

      t.timestamps
    end
  end
end
