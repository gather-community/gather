class BackfillMealsSignupParts < ActiveRecord::Migration[7.0]
  def up
    ActsAsTenant.without_tenant do 
      parts = Meals::SignupPart.all
      parts.each do |p|
        p.user_id = p.signup.household.users.first.id
        p.save!
      end
    end
  end

  def down
    ActsAsTenant.without_tenant do 
      parts = Meals::SignupPart.all
      parts.each do |p|
        p.user_id = nil
        p.save!
      end
    end
  end
end
