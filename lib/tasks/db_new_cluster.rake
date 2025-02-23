# frozen_string_literal: true

namespace :db do
  task new_cluster: :environment do
    cluster = generate_cluster
    admin = generate_admin(cluster)
    if ENV["SUPER_ADMIN"]
      puts("Generation complete. Admin credentials: #{admin.email}, #{admin.password}")
    else
      puts("Generation complete. Admin invitation sent.")
    end
  end

  def generate_cluster
    Utils::Generators::MainGenerator.new(
      cmty_name: ENV["NAME"] || "Foo Community",
      country_code: ENV.fetch("COUNTRY", nil),
      slug: ENV["SLUG"] || "foo",
      sample_data: %w[yes y].include?(ENV["SAMPLE_DATA"] || "yes"),
      photos: %w[yes y].include?(ENV["PHOTOS"] || "yes")
    ).generate
  end

  def generate_admin(cluster)
    Utils::Generators::AdminGenerator.new(
      cluster: cluster,
      email: ENV.fetch("ADMIN_EMAIL"),
      first_name: ENV.fetch("ADMIN_FNAME"),
      last_name: ENV.fetch("ADMIN_LNAME"),
      super_admin: %w[yes y].include?(ENV["SUPER_ADMIN"] || "no")
    ).generate
  end
end
