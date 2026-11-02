# frozen_string_literal: true

class CreateMessagingRegistrations < ActiveRecord::Migration[8.1]
  def change
    create_table :messaging_registrations do |t|
      t.references :cluster, null: false, foreign_key: true
      t.references :community, null: false, foreign_key: true, index: {unique: true}
      t.string :status, limit: 20, null: false, default: "draft"

      # The brand: the community's legal entity, as registered with The Campaign Registry.
      t.string :legal_name, limit: 100, null: false
      t.string :display_name, limit: 100, null: false
      t.string :entity_type, limit: 20, null: false
      t.string :ein, null: false # Encrypted, so no length limit on the ciphertext.
      t.string :street, limit: 100, null: false
      t.string :city, limit: 100, null: false
      t.string :state, limit: 2, null: false
      t.string :postal_code, limit: 10, null: false
      t.string :email, limit: 100, null: false
      t.string :phone, limit: 20, null: false
      t.string :website, limit: 100

      # The version of config/messaging/campaign.yml that was submitted.
      t.integer :campaign_version

      t.string :stripe_invoice_id
      t.string :telnyx_brand_id
      t.string :telnyx_campaign_id
      # Telnyx's own status strings, kept for display and debugging.
      t.string :brand_identity_status
      t.string :campaign_status
      t.text :failure_reason

      t.datetime :paid_at
      t.datetime :submitted_at
      t.datetime :approved_at
      t.timestamps

      t.index :stripe_invoice_id, unique: true
      t.check_constraint "status IN ('draft', 'awaiting_payment', 'brand_pending', 'campaign_pending', " \
        "'approved', 'failed')", name: "messaging_registrations_status"
      t.check_constraint "entity_type IN ('PRIVATE_PROFIT', 'NON_PROFIT', 'GOVERNMENT')",
        name: "messaging_registrations_entity_type"
    end
  end
end
