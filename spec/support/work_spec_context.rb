shared_context "work" do
  shared_examples "handles no periods" do
    context "with no period" do
      context "as coordinator" do
        let(:actor) { create(:work_coordinator) }

        scenario "index" do
          visit(index_path)
          expect(page).to have_content("There are no active work periods. Please create one first.")
        end
      end

      context "as regular user" do
        let(:actor) { create(:user) }

        scenario "index" do
          visit(index_path)
          expect(page).to have_content("It looks like your community")
        end
      end
    end
  end
end
