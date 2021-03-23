# frozen_string_literal: true

require "rails_helper"

# Tests Rankable concern via the Calendar class.
describe "Rankable" do
  let!(:decoy) { create(:calendar, community: create(:community)) }

  describe "on create" do
    context "with no existing objects in scope" do
      it do
        cal_a = create(:calendar)
        expect_rank_order(cal_a)
      end

      it do
        group = create(:calendar_group)
        expect_rank_order(group)
      end
    end

    context "with community scope" do
      context "with existing objects in scope" do
        let!(:cal_a) { create(:calendar, name: "Alpha") }
        let!(:group) { create(:calendar_group, name: "Bravo") }
        let!(:cal_b) { create(:calendar, name: "Charlie") }

        it do
          cal_c = create(:calendar)
          expect_rank_order(cal_a, group, cal_b, cal_c)
        end

        it do
          cal_c = create(:calendar, rank: 2)
          expect_rank_order(cal_a, cal_c, group, cal_b, reload_first: [3, 4])
        end

        it do
          group_b = create(:calendar_group, rank: 2)
          expect_rank_order(cal_a, group_b, group, cal_b, reload_first: [3, 4])
        end
      end
    end

    context "with group scope" do
      context "with existing objects in scope" do
        let!(:group) { create(:calendar_group, name: "Groupy") }
        let!(:cal_a) { create(:calendar, name: "Alpha", group: group) }
        let!(:cal_b) { create(:calendar, name: "Bravo", group: group) }
        let!(:cal_c) { create(:calendar, name: "Charlie", group: group) }
        let!(:decoy2) { create(:calendar, name: "Zulu") }

        it do
          cal_d = create(:calendar, group: group, rank: 3)
          expect_rank_order(cal_a, cal_b, cal_d, cal_c, reload_first: [4])
          expect_rank_order(group, decoy2)
        end
      end
    end
  end

  describe "on update" do
    context "when scope doesn't change" do
      let!(:cal_a) { create(:calendar, name: "Alpha") }
      let!(:cal_b) { create(:calendar, name: "Bravo") }
      let!(:cal_c) { create(:calendar, name: "Charlie") }

      it "adjusts correctly on move up" do
        cal_c.update!(rank: 2)
        expect_rank_order(cal_a, cal_c, cal_b, reload_first: [3])
      end

      it "adjusts correctly on move down" do
        cal_a.update!(rank: 2)
        expect_rank_order(cal_b, cal_a, cal_c, reload_first: [1])
      end
    end

    context "when scope does change" do
      let!(:group1) { create(:calendar_group, name: "Group1") }
      let!(:group2) { create(:calendar_group, name: "Group2") }
      let!(:cal_a) { create(:calendar, name: "Alpha", group: group1) }
      let!(:cal_b) { create(:calendar, name: "Bravo", group: group1) }
      let!(:cal_c) { create(:calendar, name: "Charlie", group: group1) }
      let!(:cal_d) { create(:calendar, name: "Yankee", group: group2) }
      let!(:cal_e) { create(:calendar, name: "Zulu", group: group2) }
      let!(:cal_f) { create(:calendar, name: "Mike") }
      let!(:cal_g) { create(:calendar, name: "November") }

      it do
        cal_b.update!(group: group2)
        expect_rank_order(cal_a, cal_c, reload_first: [2])
        expect_rank_order(cal_d, cal_b, cal_e, reload_first: [3])
      end

      it do
        cal_b.update!(group: group2, rank: 3)
        expect_rank_order(cal_a, cal_c, reload_first: [2])
        expect_rank_order(cal_d, cal_e, cal_b)
      end

      it do
        cal_b.update!(group: group2, rank: 1)
        expect_rank_order(cal_a, cal_c, reload_first: [2])
        expect_rank_order(cal_b, cal_d, cal_e, reload_first: [2, 3])
      end

      it do
        cal_b.update!(group: group2, rank: nil)
        expect_rank_order(cal_a, cal_c, reload_first: [2])
        expect_rank_order(cal_d, cal_e, cal_b)
      end

      it do
        cal_b.update!(group: nil, rank: nil)
        expect_rank_order(cal_a, cal_c, reload_first: [2])
        expect_rank_order(cal_d, cal_e)
        expect_rank_order(group1, group2, cal_f, cal_g, cal_b)
      end

      it do
        cal_b.update!(group: nil, rank: 2)
        expect_rank_order(cal_a, cal_c, reload_first: [2])
        expect_rank_order(cal_d, cal_e)
        expect_rank_order(group1, cal_b, group2, cal_f, cal_g, reload_first: [3, 4, 5])
      end
    end
  end

  describe "on destroy" do
    let!(:cal_a) { create(:calendar, name: "Alpha") }
    let!(:cal_b) { create(:calendar, name: "Bravo") }
    let!(:cal_c) { create(:calendar, name: "Charlie") }

    it do
      cal_a.destroy
      expect_rank_order(cal_b, cal_c, reload_first: [1, 2])
    end

    it do
      cal_b.destroy
      expect_rank_order(cal_a, cal_c, reload_first: [2])
    end

    it do
      cal_c.destroy
      expect_rank_order(cal_a, cal_b)
    end
  end

  def expect_rank_order(*objs, reload_first: [])
    before_reload = objs.map(&:rank)
    after_reload = objs.map(&:reload).map(&:rank)
    before_reload.each_with_index do |rank, idx|
      unless reload_first.include?(idx + 1)
        msg = "before reload, object expected at #{idx + 1} was at #{rank} (all: #{before_reload})"
        expect(rank).to eq(idx + 1), msg
      end
    end
    after_reload.each_with_index do |rank, idx|
      msg = "after reload, object expected at #{idx + 1} was at #{rank} (all: #{after_reload})"
      expect(rank).to eq(idx + 1), msg
    end
  end
end
