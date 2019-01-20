# frozen_string_literal: true

require "rails_helper"

describe Wiki::PagePolicy do
  describe "permissions" do
    include_context "policy permissions"
    let(:page) { create(:wiki_page, creator: user) }
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
          expect(subject).not_to permit(wikiistcmtyB, page)
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
    include_context "policy scopes"
    let(:klass) { Wiki::Page }
    let!(:objs_in_community) { create_list(:wiki_page, 2) }
    let!(:objs_in_cluster) { create_list(:wiki_page, 2, community: communityB) }

    it_behaves_like "allows regular users in community"
  end

  describe "permitted attributes" do
    include_context "policy permissions"
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
      let(:actor) { wikiistcmtyB }
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
