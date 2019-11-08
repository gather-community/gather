# frozen_string_literal: true

shared_context "work policies" do
  shared_examples_for "permits users only in some phases" do |permitted|
    Work::Period::PHASE_OPTIONS.each do |p|
      describe "for phase #{p}" do
        let(:phase) { p.to_s }
        it_behaves_like permitted.include?(p) ? "permits users in community only" : "forbids regular users"
      end
    end
  end
end
