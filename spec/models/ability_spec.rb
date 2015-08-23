require 'rails_helper'

describe Ability do
  let(:other_community){ create(:community) }

  describe "regular users" do
    it "should be able to see meals they're invited to" do
      user = create(:user)
      meal = create(:meal, community_ids: user.community_id)
      expect_can_read(user, meal)
    end

    it "should not be able to see meals they're not invited to" do
      user = create(:user)
      meal = create(:meal, communities: [other_community])
      expect(meal).not_to be_invited(user)
      expect_can_read(user, meal, false)
    end

    it "should be able to see meals they're not invited to but are working" do
      user = create(:user)
      meal = create(:meal, communities: [other_community], cleaners: [user])
      expect(meal).not_to be_invited(user)
      expect_can_read(user, meal)
    end

    it "should be able to see meals they're not invited to but are signed up for" do
      user = create(:user)
      meal = create(:meal, communities: [other_community], households: [user.household])
      expect(meal).not_to be_invited(user)
      expect_can_read(user, meal)
    end
  end

  def expect_can_read(user, meal, yn = true)
    method = yn ? :to : :not_to
    expect(user).send(method, be_able_to(:read, meal))
    expect(user).send(method, be_able_to_index_by_sql(meal))
  end
end
