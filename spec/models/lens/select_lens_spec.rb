# frozen_string_literal: true

require "rails_helper"

# Simple id/name class.
class Foo
  include ActiveModel::Model

  attr_accessor :id, :name

  def ==(other)
    other.is_a?(Foo) && other.id == id
  end

  def eql?(other)
    other == self
  end

  delegate :hash, to: :id
end

# Simple lens for test purposes
class BasicSelectLens < Lens::SelectLens
  param_name :view
  possible_options %i[album table tableall]
  i18n_key "simple_form.options.user.view"

  protected

  def excluded_options
    route_params[:foo] ? [:tableall] : []
  end
end

# Lens with multiple option types for test purposes
class ComplexSelectLens < Lens::SelectLens
  param_name :view
  possible_options [:album, ["TABLE", 1], "---", Foo.new(id: 12, name: "TableAll")]
  i18n_key "simple_form.options.user.view"
end

describe Lens::SelectLens do
  let(:community) { create(:community) }
  let(:context) { double }
  let(:base_option) { nil }
  let(:initial_selection) { nil }
  let(:storage) { double(action_store: {}) }
  let(:lens) do
    params = {options: {}, context: context, route_params: route_params, storage: storage, set: nil}
    params[:options][:base_option] = base_option unless base_option.nil?
    params[:options][:initial_selection] = initial_selection unless initial_selection.nil?
    params[:options][:clearable] = clearable
    klass.new(**params)
  end

  describe "value initialization" do
    let(:klass) { BasicSelectLens }
    subject(:value) { lens.value }

    shared_examples_for "correct value initialization" do
      context "when no route param given" do
        let(:route_params) { {} }
        it { is_expected.to be_nil }
      end

      context "when no route param given but initial_selection given" do
        let(:route_params) { {} }
        let(:initial_selection) { :album }
        it { is_expected.to eq("album") }
      end

      context "when route param and initial_selection given" do
        let(:route_params) { {view: "table"} }
        let(:initial_selection) { :album }
        it { is_expected.to eq("table") }
      end

      context "when invalid route param given" do
        let(:route_params) { {view: "tablez"} }
        it { is_expected.to be_nil }
      end

      context "when invalid value stored in storage" do
        let(:route_params) { {} }
        let(:storage) { double(action_store: {"view" => "tablez"}) }
        it { is_expected.to be_nil }
      end
    end

    context "with clearable lens" do
      let(:clearable) { true }
      it_behaves_like "correct value initialization"
    end

    context "with non-clearable lens" do
      let(:clearable) { false }
      it_behaves_like "correct value initialization"
    end
  end

  describe "#clearable_and_active?" do
    let(:klass) { BasicSelectLens }
    subject(:clearable_and_active) { lens.clearable_and_active? }

    context "with clearable lens" do
      let(:clearable) { true }

      context "without explicitly defined base" do
        context "when no value is given" do
          let(:route_params) { {} }
          it { is_expected.to be(false) }
        end

        context "when first option is explicitly given" do
          let(:route_params) { {view: "album"} }
          it { is_expected.to be(false) }
        end

        context "when initial_selection is specified" do
          let(:route_params) { {} }
          let(:initial_selection) { :table }
          it { is_expected.to be(true) }
        end

        context "when other value is given" do
          let(:route_params) { {view: "table"} }
          it { is_expected.to be(true) }
        end
      end

      context "with explicitly defined base" do
        let(:base_option) { :tableall }

        context "when no value is given" do
          let(:route_params) { {} }
          it { is_expected.to be(false) }
        end

        context "when explicitly defined base is given" do
          let(:route_params) { {view: "tableall"} }
          it { is_expected.to be(false) }
        end

        context "when value given is not the base" do
          let(:route_params) { {view: "table"} }
          it { is_expected.to be(true) }
        end

        context "when non-base value set as initial_selection" do
          let(:route_params) { {} }
          let(:initial_selection) { :table }
          it { is_expected.to be(true) }
        end
      end
    end

    context "with non-clearable lens" do
      let(:clearable) { false }
      let(:base_option) { :tableall }

      context "without explicitly defined base" do
        context "when no value is given" do
          let(:route_params) { {} }
          it { is_expected.to be(false) }
        end

        context "when first option is explicitly given" do
          let(:route_params) { {view: "album"} }
          it { is_expected.to be(false) }
        end

        context "when other value is given" do
          let(:route_params) { {view: "table"} }
          it { is_expected.to be(false) }
        end
      end

      context "with explicitly defined base" do
        let(:base_option) { :tableall }

        context "when no value is given" do
          let(:route_params) { {} }
          it { is_expected.to be(false) }
        end

        context "when explicitly defined base is given" do
          let(:route_params) { {view: "tableall"} }
          it { is_expected.to be(false) }
        end

        context "when value given is not the base" do
          let(:route_params) { {view: "table"} }
          it { is_expected.to be(false) }
        end
      end
    end
  end

  describe "#selection" do
    let(:klass) { ComplexSelectLens }
    subject(:selection) { lens.selection }

    context "with clearable lens" do
      let(:clearable) { true }

      context "when nothing selected" do
        let(:route_params) { {} }
        it { is_expected.to eq(:album) }
      end

      context "when symbol (base) selected" do
        let(:route_params) { {view: "album"} }
        it { is_expected.to eq(:album) }
      end

      context "when pair selected" do
        let(:route_params) { {view: "1"} }
        it { is_expected.to eq(["TABLE", 1]) }
      end

      context "when object selected" do
        let(:route_params) { {view: "12"} }
        it { is_expected.to eq(Foo.new(id: 12, name: "TableAll")) }
      end
    end

    context "with non-clearable lens" do
      let(:clearable) { false }

      context "when nothing selected" do
        let(:route_params) { {} }
        it { is_expected.to eq(:album) }
      end

      context "when symbol (base) selected" do
        let(:route_params) { {view: "album"} }
        it { is_expected.to eq(:album) }
      end

      context "when pair selected" do
        let(:route_params) { {view: "1"} }
        it { is_expected.to eq(["TABLE", 1]) }
      end

      context "when object selected" do
        let(:route_params) { {view: "12"} }
        it { is_expected.to eq(Foo.new(id: 12, name: "TableAll")) }
      end
    end
  end

  describe "#render" do
    let(:view_context) { double(select_tag: nil) }
    let(:clearable) { true }

    before do
      expect(lens).to receive(:h).twice.and_return(view_context)
    end

    context "with symbol-based lens" do
      let(:klass) { BasicSelectLens }

      shared_examples_for "has no selected option" do
        it "calls expected methods" do
          expect(view_context).to receive(:options_for_select)
            .with([["Album", nil], %w[Table table], ["Table w/ Inactive", "tableall"]], nil)
            .and_return("<option ...>")
          expect(view_context).to receive(:select_tag).with(
            :view,
            "<option ...>",
            class: "form-control view-lens",
            "data-param-name": :view,
            onchange: "this.form.submit();"
          ).and_return("<select ...>")
          expect(lens.render).to eq("<select ...>")
        end
      end

      context "when base value chosen explicitly" do
        let(:route_params) { {view: "album"} }
        it_behaves_like "has no selected option"
      end

      context "when base value but nothing selected" do
        let(:route_params) { {} }
        it_behaves_like "has no selected option"
      end

      context "with initial_selection" do
        let(:initial_selection) { :table }

        context "with no route params" do
          let(:route_params) { {} }

          it "selects the initial selection" do
            expect(view_context).to receive(:options_for_select)
              .with([["Album", nil], %w[Table table], ["Table w/ Inactive", "tableall"]], "table")
              .and_return("<option ...>")
            lens.render
          end
        end

        context "with blank route params" do
          let(:route_params) { {view: ""} }

          it "selects the base" do
            expect(view_context).to receive(:options_for_select)
              .with([["Album", nil], %w[Table table], ["Table w/ Inactive", "tableall"]], nil)
              .and_return("<option ...>")
            lens.render
          end
        end

        context "with explicit route params" do
          let(:route_params) { {view: "tableall"} }

          it "overrides the initial selection" do
            expect(view_context).to receive(:options_for_select)
              .with([["Album", nil], %w[Table table], ["Table w/ Inactive", "tableall"]], "tableall")
              .and_return("<option ...>")
            lens.render
          end
        end

        context "with value in store" do
          let(:route_params) { {} }
          let(:storage) { double(action_store: {"view" => "tableall"}) }

          it "overrides the initial selection" do
            expect(view_context).to receive(:options_for_select)
              .with([["Album", nil], %w[Table table], ["Table w/ Inactive", "tableall"]], "tableall")
              .and_return("<option ...>")
            lens.render
          end
        end
      end

      context "when other value chosen" do
        let(:route_params) { {view: "table"} }

        it "passes expected selected option" do
          expect(view_context).to receive(:options_for_select)
            .with([["Album", nil], %w[Table table], ["Table w/ Inactive", "tableall"]], "table")
            .and_return("<option ...>")
          expect(view_context).to receive(:select_tag) do |_p, _q, options|
            expect(options[:prompt]).to be_nil
          end
          lens.render
        end
      end

      context "when options excluded" do
        let(:route_params) { {foo: 1} }

        it "passes expected options" do
          expect(view_context).to receive(:options_for_select)
            .with([["Album", nil], %w[Table table]], nil).and_return("<option ...>")
          lens.render
        end
      end
    end

    context "with lens with different option types" do
      let(:klass) { ComplexSelectLens }

      context "when lens is clearable" do
        let(:clearable) { true }

        context "with no explicit base" do
          context "when pair is selected" do
            let(:route_params) { {view: "1"} }

            it "renders properly" do
              expect(view_context).to receive(:options_for_select)
                .with([["Album", nil], %w[TABLE 1], ["---", nil], %w[TableAll 12]], "1")
                .and_return("<option ...>")
              lens.render
            end
          end

          context "when object is selected" do
            let(:route_params) { {view: "12"} }

            it "renders properly" do
              expect(view_context).to receive(:options_for_select)
                .with([["Album", nil], %w[TABLE 1], ["---", nil], %w[TableAll 12]], "12")
                .and_return("<option ...>")
              lens.render
            end
          end
        end

        context "when pair is base and nothing is selected" do
          let(:base_option) { ["TABLE", 1] }
          let(:route_params) { {} }

          it "no option tag is selected" do
            expect(view_context).to receive(:options_for_select)
              .with([["TABLE", nil], %w[Album album], ["---", nil], %w[TableAll 12]], nil)
              .and_return("<option ...>")
            lens.render
          end
        end

        context "when object is base and nothing is selected" do
          let(:base_option) { Foo.new(id: 12, name: "TableAll") }
          let(:route_params) { {} }

          it "no option tag is selected" do
            expect(view_context).to receive(:options_for_select)
              .with([["TableAll", nil], %w[Album album], %w[TABLE 1], ["---", nil]], nil)
              .and_return("<option ...>")
            lens.render
          end
        end
      end

      context "when lens is not clearable" do
        let(:clearable) { false }

        context "with no explicit base" do
          context "when pair is selected" do
            let(:route_params) { {view: "1"} }

            it "renders properly" do
              expect(view_context).to receive(:options_for_select)
                .with([%w[Album album], %w[TABLE 1], ["---", nil], %w[TableAll 12]], "1")
                .and_return("<option ...>")
              lens.render
            end
          end

          context "when object is selected" do
            let(:route_params) { {view: "12"} }

            it "renders properly" do
              expect(view_context).to receive(:options_for_select)
                .with([%w[Album album], %w[TABLE 1], ["---", nil], %w[TableAll 12]], "12")
                .and_return("<option ...>")
              lens.render
            end
          end
        end

        context "when pair is base and nothing is selected" do
          let(:base_option) { ["TABLE", 1] }
          let(:route_params) { {} }

          it "renders properly" do
            expect(view_context).to receive(:options_for_select)
              .with([%w[TABLE 1], %w[Album album], ["---", nil], %w[TableAll 12]], nil)
              .and_return("<option ...>")
            lens.render
          end
        end

        context "when object is base and nothing is selected" do
          let(:base_option) { Foo.new(id: 12, name: "TableAll") }
          let(:route_params) { {} }

          it "renders properly" do
            expect(view_context).to receive(:options_for_select)
              .with([%w[TableAll 12], %w[Album album], %w[TABLE 1], ["---", nil]], nil)
              .and_return("<option ...>")
            lens.render
          end
        end
      end
    end
  end
end
