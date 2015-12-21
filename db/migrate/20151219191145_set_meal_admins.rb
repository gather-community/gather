class SetMealAdmins < ActiveRecord::Migration
  def up
    Community.all.each do |c|
      case c.name
      when "Touchstone" then c.settings[:meals_admin] = "meals@touchstonecohousing.org"
      when "Sunward" then c.settings[:meals_admin] = "ed@sunward.org"
      when "Great Oak" then c.settings[:meals_admin] = "eat@gocoho.org"
      end

      c.save!
    end
  end
end
