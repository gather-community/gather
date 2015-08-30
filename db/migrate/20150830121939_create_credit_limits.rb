class CreateCreditLimits < ActiveRecord::Migration
  def change
    create_table :credit_limits do |t|
      t.references :household, foreign_key: true, index: true, null: false
      t.references :community, foreign_key: true, index: true, null: false
      t.integer :limit, null: false
      t.boolean :exceeded, null: false, default: false

      t.timestamps null: false
    end

    Household.all.each do |h|
      Community.all.each do |c|
        if CreditLimit.find_by(household: h, community: c).nil?
          CreditLimit.create!(household: h, community: c, limit: 50)
        end
      end
    end
  end
end
