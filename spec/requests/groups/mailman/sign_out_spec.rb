# frozen_string_literal: true

require "rails_helper"

describe "mailman user sign out" do
  let!(:list) { create(:group_mailman_list) }
  let!(:mm_user) { create(:group_mailman_user) }
  let(:actor) { mm_user.user }

  before do
    use_user_subdomain(actor)
    sign_in(actor)
  end

  it "enqueues single sign out" do
    expect { delete("/people/users/sign-out") }
      .to have_enqueued_job(Groups::Mailman::SingleSignOnJob).with(user_id: actor.id, action: :sign_out)
  end
end
