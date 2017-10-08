require 'rails_helper'

describe Wiki::PagePolicy do
  describe "permissions" do
    include_context "policy objs"

    let(:page) { build(:wiki_page, community: community, creator: user) }
    let(:record) { page }

    permissions :all?, :show?, :new?, :edit?, :update?, :destroy?, :history?, :compare? do
      it_behaves_like "permits users in community only"
    end
  end
end
