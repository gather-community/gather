# frozen_string_literal: true

namespace :db do
  task new_cluster: :environment do
    Utils::FakeData::MainGenerator.new(
      cmty_name: ENV["CLUSTER"] || "Foo Community",
      slug: ENV["SLUG"] || "foo",
      admin_attrs: {
        email: ENV.fetch("ADMIN_EMAIL"),
        first_name: ENV.fetch("ADMIN_FNAME"),
        last_name: ENV.fetch("ADMIN_LNAME"),
        super_admin: %w[yes y].include?(ENV["SUPER_ADMIN"] || "no")
      },
      sample_data: %w[yes y].include?(ENV["SAMPLE_DATA"] || "yes"),
      photos: %w[yes y].include?(ENV["PHOTOS"] || "yes")
    ).generate
  end
end
