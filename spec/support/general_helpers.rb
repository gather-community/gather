module GeneralHelpers
  def fixture_file_path(name)
    "#{Rails.root}/spec/fixtures/#{name}"
  end

  def stub_translation(key, msg, expect_defaults: nil)
    original_translate = I18n.method(:translate)
    allow(I18n).to receive(:translate) do |key_arg, options|
      if key == key_arg
        expect(options[:default]).to eq expect_defaults if expect_defaults
        msg
      else
        original_translate.call(key_arg, options)
      end
    end
  end
end
