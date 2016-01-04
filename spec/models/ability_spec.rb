require 'rails_helper'

describe Ability do
   # Force two communities to be created. Users will be in first one by default.
  let!(:community){ default_community }
  let!(:other_community){ create(:community) }

  shared_examples_for :invite_only do
    it "should be able to see meals they're invited to" do
      meal = create(:meal, community_ids: user.community_id)
      expect_can_read(user, meal)
    end

    it "should not be able to see meals they're not invited to" do
      meal = create(:meal, communities: [other_community])
      expect(meal).not_to be_invited(user)
      expect_can_read(user, meal, false)
    end

    it "should be able to see meals they're not invited to but are working" do
      meal = create(:meal, communities: [other_community], cleaners: [user])
      expect(meal).not_to be_invited(user)
      expect_can_read(user, meal)
    end

    it "should be able to see meals they're not invited to but are signed up for" do
      meal = create(:meal, communities: [other_community], households: [user.household])
      expect(meal).not_to be_invited(user)
      expect_can_read(user, meal)
    end
  end

  describe "regular users" do
    let(:user){ create(:user) }
    it_should_behave_like :invite_only
  end

  describe "admins" do
    let(:user){ create(:user, admin: true) }
    it_should_behave_like :invite_only
  end

  def expect_can_read(user, meal, yn = true)
    method = yn ? :to : :not_to
    expect(user).send(method, be_able_to(:read, meal))
    expect(user).send(method, be_able_to_index_by_sql(meal))
  end
end
