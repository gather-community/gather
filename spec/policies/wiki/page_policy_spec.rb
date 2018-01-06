require 'rails_helper'

describe Wiki::PagePolicy do
  include_context "policy objs"

  describe "permissions" do
    let(:page) { build(:wiki_page, community: community, creator: user) }
    let(:record) { page }

    permissions :index?, :all?, :show?, :new?, :edit?, :create?, :update?, :history?, :compare? do
      it_behaves_like "permits users in community only"
    end

    permissions :update? do
      context "with restricted page" do
        before { page.editable_by = "wikiist" }

        it "permits admins" do
          expect(subject).to permit(admin, page)
        end

        it "permits wikiist" do
          expect(subject).to permit(wikiist, page)
        end

        it "denies wikiist from other community" do
          expect(subject).not_to permit(wikiist_in_cmtyB, page)
        end

        it "denies creator" do
          expect(subject).not_to permit(user, page)
        end

        it "denies regular user" do
          expect(subject).not_to permit(other_user, page)
        end
      end
    end

    permissions :destroy? do
      it "permits admins" do
        expect(subject).to permit(admin, page)
      end

      it "permits creator" do
        expect(subject).to permit(user, page)
      end

      it "permits wikiist" do
        expect(subject).to permit(wikiist, page)
      end

      it "denies other users in community" do
        expect(subject).not_to permit(other_user, page)
      end

      it "denies removal of sample page" do
        page.role = "sample"
        expect(subject).not_to permit(admin, page)
      end
    end
  end

  describe "scope" do
    let!(:page1) { create(:wiki_page, community: community) }
    let!(:page2) { create(:wiki_page, community: community) }
    let!(:page3) { create(:wiki_page, community: communityB) }
    subject { Wiki::PagePolicy::Scope.new(actor, Wiki::Page.all).resolve }

    before do
      save_policy_objects!(community, communityB, user, cluster_admin)
    end

    context "for regular users" do
      let(:actor) { user }
      it { is_expected.to contain_exactly(page1, page2) }
    end

    # TODO: refactor to abstract this kind of check into policy spec context file
    context "for cluster admins" do
      let(:actor) { cluster_admin }
      it { is_expected.to contain_exactly(page1, page2, page3) }
    end
  end

  describe "permitted attributes" do
    subject { Wiki::PagePolicy.new(actor, Wiki::Page.new(community: community)).permitted_attributes }

    shared_examples_for "regular user" do
      it "should allow setting editable_by" do
        expect(subject).to contain_exactly(:title, :content, :comment)
      end
    end

    shared_examples_for "wikiist and above" do
      it "should allow setting editable_by" do
        expect(subject).to contain_exactly(:title, :content, :comment, :editable_by, :data_source)
      end
    end

    context "for regular users" do
      let(:actor) { user }
      it_behaves_like "regular user"
    end

    context "for outside wikiist" do
      let(:actor) { wikiist_in_cmtyB }
      it_behaves_like "regular user"
    end

    context "for wikiists" do
      let(:actor) { wikiist }
      it_behaves_like "wikiist and above"
    end

    context "for admins" do
      let(:actor) { admin }
      it_behaves_like "wikiist and above"
    end
  end
end
