# frozen_string_literal: true

require "rails_helper"

describe CustomFields::Entries::BasicEntry do
  let(:field) { CustomFields::Fields::EnumField.new(key: "foo", options: %w[a b], required: true) }
  let(:entry) { described_class.new(field: field, hash: {foo: "b"}) }

  it "should delegate field methods" do
    expect(entry.key).to eq(field.key)
    expect(entry.type).to eq(field.type)
    expect(entry.options).to eq(field.options)
    expect(entry.required).to be(field.required)
  end

  describe "defaults" do
    let(:field) { CustomFields::Fields::StringField.new(key: "foo", default: "bar") }

    context "when initialized with empty hash" do
      let(:entry) { described_class.new(field: field, hash: {}) }

      it "should set key in hash to default and return default as value" do
        expect(entry.hash).to eq(foo: "bar")
        expect(entry.value).to eq("bar")
      end
    end

    context "when initialized with explicit nil value" do
      let(:entry) { described_class.new(field: field, hash: {foo: nil}) }

      it "should still use default" do
        expect(entry.hash).to eq(foo: "bar")
        expect(entry.value).to eq("bar")
      end
    end

    context "when initialized with non-nil value" do
      let(:entry) { described_class.new(field: field, hash: {foo: "baz"}) }

      it "should ignore default" do
        expect(entry.hash).to eq(foo: "baz")
        expect(entry.value).to eq("baz")
      end
    end
  end

  describe "input_params" do
    let(:root) { double }

    before do
      allow(root).to receive(:i18n_key) { |t, *_a| "custom_fields.#{t}.model_x.attrib_y" }
    end

    context "for string field" do
      let(:field) { CustomFields::Fields::StringField.new(key: "foo") }
      let(:entry) { described_class.new(field: field, hash: {foo: "bar"}, parent: root) }

      context "with no translations defined" do
        context "with no explicit label/hint/placeholder defined" do
          it "should not include label/hint/placeholder params" do
            expect(entry.input_params).to eq(
              as: :string,
              input_html: {value: "bar"},
              wrapper_html: {class: "custom-field custom-field-string"}
            )
          end
        end

        context "with explicit label/hint/placeholder defined" do
          let(:field) do
            CustomFields::Fields::StringField.new(key: "foo", label: "Foo", hint: "Foo!",
                                                  placeholder: "Foo...")
          end

          it "should include label/hint/placeholder" do
            expect(entry.input_params).to eq(
              as: :string,
              label: "Foo",
              hint: "Foo!",
              placeholder: "Foo...",
              input_html: {value: "bar"},
              wrapper_html: {class: "custom-field custom-field-string"}
            )
          end
        end
      end

      context "with translations defined" do
        before do
          I18n.backend.send(:init_translations)
          I18n.backend.store_translations(:en,
                                          custom_fields: {
                                            labels: {model_x: {attrib_y: {foo: "The Foo"}}},
                                            hints: {model_x: {attrib_y: {foo: "Think about foos"}}},
                                            placeholders: {model_x: {attrib_y: {foo: "Some foo"}}}
                                          })
        end

        after do
          I18n.backend = I18n::Backend::Simple.new
        end

        context "with no explicit label/hint/placeholder defined" do
          it "should use translated label/hint/placeholder" do
            expect(entry.input_params).to eq(
              as: :string,
              input_html: {value: "bar"},
              label: "The Foo",
              hint: "Think about foos",
              placeholder: "Some foo",
              wrapper_html: {class: "custom-field custom-field-string"}
            )
          end
        end

        context "with explicit label/hint/placeholder defined" do
          let(:field) do
            CustomFields::Fields::StringField.new(key: "foo", label: "Foo", hint: "Foo!",
                                                  placeholder: "Foo...")
          end

          it "should use explicit label/hint/placeholder" do
            expect(entry.input_params).to eq(
              as: :string,
              input_html: {value: "bar"},
              label: "Foo",
              hint: "Foo!",
              placeholder: "Foo...",
              wrapper_html: {class: "custom-field custom-field-string"}
            )
          end
        end
      end
    end

    context "for enum field" do
      let(:field) { CustomFields::Fields::EnumField.new(key: "foo", options: %w[a b], include_blank: "bar") }
      let(:entry) { described_class.new(field: field, hash: {foo: "b"}, parent: root) }

      context "with no translations defined" do
        it "should return collection with default labels" do
          expect(entry.input_params).to eq(
            as: :select,
            collection: [%w[a a], %w[b b]],
            value_method: :first,
            label_method: :last,
            selected: "b",
            wrapper_html: {class: "custom-field custom-field-enum"},
            include_blank: "bar"
          )
        end
      end

      context "with translations defined" do
        before do
          I18n.backend.send(:init_translations)
          I18n.backend.store_translations(:en,
                                          custom_fields: {options: {model_x: {attrib_y: {foo: {a: "Alpha",
                                                                                               b: "Bravo"}}}}})
        end

        after do
          I18n.backend = I18n::Backend::Simple.new
        end

        it "should return collection with translated options" do
          expect(entry.input_params).to eq(
            as: :select,
            collection: [%w[a Alpha], %w[b Bravo]],
            value_method: :first,
            label_method: :last,
            selected: "b",
            wrapper_html: {class: "custom-field custom-field-enum"},
            include_blank: "bar"
          )
        end
      end
    end

    context "for boolean field" do
      let(:field) { CustomFields::Fields::BooleanField.new(key: "foo") }
      let(:entry) { described_class.new(field: field, hash: {foo: true}, parent: root) }

      it "should return as boolean" do
        expect(entry.input_params).to eq(
          as: :boolean,
          input_html: {checked: true},
          wrapper_html: {class: "custom-field custom-field-boolean"}
        )
      end
    end

    context "for text field" do
      let(:field) { CustomFields::Fields::TextField.new(key: "foo") }
      let(:entry) { described_class.new(field: field, hash: {foo: "bar"}, parent: root) }

      it "should return empty hash" do
        expect(entry.input_params).to eq(
          as: :text,
          input_html: {value: "bar"},
          wrapper_html: {class: "custom-field custom-field-text"}
        )
      end
    end
  end
end
