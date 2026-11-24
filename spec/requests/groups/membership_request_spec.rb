# frozen_string_literal: true

require "rails_helper"

# Joining and leaving through the UI is covered by spec/system/groups/group_spec.rb. This covers the
# button being clicked again on a stale page, which a browser spec can't easily reproduce.
describe "group join and leave" do
  let(:actor) { create(:user) }
  let(:group) { create(:group, availability: "open", communities: [actor.community]) }

  before do
    use_user_subdomain(actor)
    sign_in(actor)
  end

  it "treats joining twice as joined" do
    put("/groups/#{group.id}/join")
    put("/groups/#{group.id}/join")
    expect(response).to redirect_to("/groups/#{group.id}")
    expect(flash[:success]).to eq("You have successfully joined the group \"#{group.name}\".")
    expect(group.memberships.where(user: actor).count).to eq(1)
  end

  it "treats leaving twice as left" do
    group.join(actor)
    put("/groups/#{group.id}/leave")
    put("/groups/#{group.id}/leave")
    expect(response).to redirect_to("/groups/#{group.id}")
    expect(flash[:success]).to eq("You have successfully left the group \"#{group.name}\".")
    expect(group.memberships.where(user: actor).count).to eq(0)
  end

  it "still forbids joining a hidden group" do
    hidden = create(:group, availability: "hidden", communities: [actor.community])
    expect { put("/groups/#{hidden.id}/join") }.to raise_error(Pundit::NotAuthorizedError)
  end
end
