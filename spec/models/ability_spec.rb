require 'rails_helper'

describe Ability do
  describe "regular users" do
    it "should be able to see meals they're invited to" do
      user = create(:user)
      meal = create(:meal, community_ids: user.community_id)
      expect(user).to be_able_to(:read, meal)
      expect(user).to be_able_to_index_by_sql(meal)
    end

    it "should not be able to see meals they're not invited to" do
      user = create(:user)
      meal = create(:meal, communities: [create(:community)])
      expect(meal).not_to be_invited(user)
      expect(user).not_to be_able_to(:read, meal)
      expect(user).not_to be_able_to_index_by_sql(meal)
    end

    it "should be able to see meals they're not invited to but are working" do
      user = create(:user)
      meal = create(:meal, communities: [create(:community)], cleaners: [user])
      expect(meal).not_to be_invited(user)
      expect(user).to be_able_to(:read, meal)
      expect(user).to be_able_to_index_by_sql(meal)
    end

    it "should be able to see meals they're not invited to but are signed up for" do
      user = create(:user)
      meal = create(:meal, communities: [create(:community)], households: [user.household])
      expect(meal).not_to be_invited(user)
      expect(user).to be_able_to(:read, meal)
      expect(user).to be_able_to_index_by_sql(meal)
    end
  end
end
