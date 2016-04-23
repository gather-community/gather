require 'rails_helper'

RSpec.describe CookMenuReminderJob, type: :model do
  describe "remindable_assignments" do
    let(:user1) { create(:user) }
    let(:user2) { create(:user) }
    let!(:meal1) { create(:meal, meal1_traits, head_cook: user1, served_at: Time.now + 4.days) }
    let!(:meal2) { create(:meal, meal2_traits, head_cook: user2, served_at: Time.now + 9.days) }
    let!(:decoy) { create(:meal, head_cook: user2, cleaners: [user1], served_at: Time.now + 13.days) }
    subject { CookMenuReminderJob.new.send(:remindable_assignments) }

    context "both meals without menus" do
      let(:meal1_traits) { nil }
      let(:meal2_traits) { nil }

      it "should return both assignments" do
        expect(subject).to contain_exactly(meal1.head_cook_assign, meal2.head_cook_assign)
      end

      context "with early reminders already sent for both meals" do
        before do
          meal1.head_cook_assign.update_attribute(:reminder_count, 1)
          meal2.head_cook_assign.update_attribute(:reminder_count, 1)
        end

        it "should return sooner assignment only" do
          expect(subject).to contain_exactly(meal1.head_cook_assign)
        end
      end
    end

    context "menu for sooner meal only" do
      let(:meal1_traits) { :with_menu }
      let(:meal2_traits) { nil }

      it "should return later assignment only" do
        expect(subject).to contain_exactly(meal2.head_cook_assign)
      end
    end

    context "both meals with menus" do
      let(:meal1_traits) { :with_menu }
      let(:meal2_traits) { :with_menu }

      it "should return neither assignment" do
        expect(subject).to be_empty
      end
    end
  end

end