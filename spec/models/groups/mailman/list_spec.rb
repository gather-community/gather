# frozen_string_literal: true

require "rails_helper"

describe Groups::Mailman::List do
  describe "factory" do
    it "is valid" do
      create(:group_mailman_list)
    end
  end

  describe "validation" do
    shared_examples_for "validates addresses" do |attrib|
      context "with valid lines and one blank line" do
        let(:addresses) { "foo@example.com\n   \n  Bar Q. <bar@example.com>\nbaz@example.com" }
        it { is_expected.to be_valid }
      end

      context "with format error" do
        let(:addresses) { "foo@example.com\nBar Q. <bar@example.com" }
        it { is_expected.to have_errors(attrib => /Error on line 2 \(Bar Q. <bar@example.com\)/) }
      end

      context "with invalid address" do
        let(:addresses) { "fooexample.com\nBar Q. <bar@example.com>" }
        it { is_expected.to have_errors(attrib => /Error on line 1 \(fooexample.com\)/) }
      end

      context "with multiple errors" do
        let(:addresses) { "fooexample.com\nbarexample.com" }

        it "just shows the first" do
          is_expected.to have_errors(attrib => /Error on line 1 \(fooexample.com\)/)
        end
      end
    end

    describe "outside_members" do
      subject(:list) { build(:group_mailman_list, outside_members: addresses) }
      it_behaves_like "validates addresses", :outside_members
    end

    describe "outside_senders" do
      subject(:list) { build(:group_mailman_list, outside_senders: addresses) }
      it_behaves_like "validates addresses", :outside_senders
    end
  end

  describe "outside address cleanup" do
    let(:addresses) { " a@b.com  \n\n  Jo Bol <c@d.com>\nPhil Plomp (Junk) <e@f.com>" }

    shared_examples_for "cleans up addresses" do |attrib|
      it do
        expect(list[attrib]).to eq("a@b.com\nJo Bol <c@d.com>\nPhil Plomp <e@f.com> (Junk)")
      end
    end

    describe "outside_members" do
      subject(:list) { create(:group_mailman_list, outside_members: addresses) }
      it_behaves_like "cleans up addresses", :outside_members
    end

    describe "outside_senders" do
      subject(:list) { create(:group_mailman_list, outside_senders: addresses) }
      it_behaves_like "cleans up addresses", :outside_senders
    end
  end
end
