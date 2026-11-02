# frozen_string_literal: true

module Gather
  # Builds the static pages in public/ (404.html, 500.html, offline.html, ...) from the templates in
  # app/views/error_pages, so their text comes from the locale files like everything else.
  #
  # The default locale's page is written to public/404.html. Each other translated locale gets
  # public/404.<locale>.html, which is what Rails' exception app (ActionDispatch::PublicExceptions) and
  # ApplicationControllable#render_error_page look for first. They're only served in a locale the request
  # was given, so the i18n feature flag (see Gather::Locales) decides whether anyone sees them.
  #
  # The pages are static so they can be served when the app is down, so they're generated ahead of time with
  # `rake error_pages:generate` and committed. spec/i18n_spec.rb fails if they're out of date.
  module ErrorPages
    NAMES = %w[400 403 404 406-unsupported-browser 422 500 offline].freeze

    # Writes every page for every translated locale into `dir`.
    def self.write_all(dir = Rails.public_path)
      files.each { |path, html| File.write(File.join(dir, path), html) }
    end

    # A hash of public/-relative file name => rendered HTML for every page and translated locale.
    def self.files
      Locales::TRANSLATED.product(NAMES).to_h do |locale, name|
        [file_name(name, locale), render(name, locale)]
      end
    end

    # The public/-relative file name for a page in a locale.
    def self.file_name(name, locale)
      locale.to_sym == I18n.default_locale ? "#{name}.html" : "#{name}.#{locale}.html"
    end

    def self.render(name, locale)
      # Development wraps rendered templates in <!-- BEGIN/END filename --> comments. They mustn't end up in
      # the committed files, which would also then differ depending on the environment they were built in.
      annotate = ActionView::Base.annotate_rendered_view_with_filenames
      ActionView::Base.annotate_rendered_view_with_filenames = false
      I18n.with_locale(locale) do
        html = ApplicationController.render(template: "error_pages/#{name}", layout: false, formats: [:html])
        html.end_with?("\n") ? html : "#{html}\n"
      end
    ensure
      ActionView::Base.annotate_rendered_view_with_filenames = annotate
    end
  end
end
