# frozen_string_literal: true

# This file is not teh cleanest and doesn't have test coverage but that will all change when we do the new one.
namespace :db do
  ARGS = %i[cluster_name slug google_id first_name last_name populate].freeze
  task :new_cluster, ARGS => :environment do |_t, args|
    unless ARGS.all? { |k| args.send(k).present? }
      abort("Usage: rake db:new_cluster[<cluster_name>,<slug>,<admin google ID>,"\
        "<first_name>,<last_name>,<populate (y or n)>]")
    end
    ActiveRecord::Base.transaction do
      cluster = Cluster.create!(name: args.cluster_name)
      ActsAsTenant.with_tenant(cluster) do
        cmty = Community.create!(name: args.cluster_name, slug: args.slug)
        roles = [
          Meals::Role.create!(
            community: cmty,
            count_per_meal: 1,
            title: "Head Cook",
            special: "head_cook",
            description: "Plans and supervises meal prep.",
            time_type: "date_only",
            reminders_attributes: [{rel_magnitude: 3, rel_unit_sign: "days_before"}]
          ),
          Meals::Role.create!(
            community: cmty,
            count_per_meal: 2,
            title: "Assistant Cook",
            description: "Helps with meal prep as directed by the head cook.",
            time_type: "date_time",
            shift_start: -120,
            shift_end: 0,
            reminders_attributes: [{rel_magnitude: 1, rel_unit_sign: "days_before"}]
          ),
          Meals::Role.create!(
            community: cmty,
            count_per_meal: 3,
            title: "Cleaner",
            description: "Cleans up after the meal.",
            time_type: "date_time",
            shift_start: 60,
            shift_end: 150,
            reminders_attributes: [{rel_magnitude: 1, rel_unit_sign: "days_before"}]
          )
        ]
        types = [
          Meals::Type.create!(community: cmty, name: "Adult Meat", subtype: "Meat"),
          Meals::Type.create!(community: cmty, name: "Adult Veg", subtype: "Veg"),
          Meals::Type.create!(community: cmty, name: "Big Kid Meat", subtype: "Meat", discounted: true),
          Meals::Type.create!(community: cmty, name: "Big Kid Veg", subtype: "Veg", discounted: true),
          Meals::Type.create!(community: cmty, name: "Little Kid Meat", subtype: "Meat", discounted: true),
          Meals::Type.create!(community: cmty, name: "Little Kid Veg", subtype: "Veg", discounted: true),
          Meals::Type.create!(community: cmty, name: "Senior Meat", subtype: "Meat", discounted: true),
          Meals::Type.create!(community: cmty, name: "Senior Veg", subtype: "Veg", discounted: true),
          Meals::Type.create!(community: cmty, name: "Teen Meat", subtype: "Meat", discounted: true),
          Meals::Type.create!(community: cmty, name: "Teen Veg", subtype: "Veg", discounted: true)
        ]
        formula = Meals::Formula.create!(
          community: cmty,
          is_default: true,
          name: "Default Formula",
          adult_meat: 1,
          adult_veg: 1,
          big_kid_meat: 0.5,
          big_kid_veg: 0.4,
          little_kid_meat: 0,
          little_kid_veg: 0,
          senior_meat: 0.9,
          senior_veg: 0.8,
          teen_meat: 0.5,
          teen_veg: 0.4,
          meal_calc_type: "share",
          pantry_calc_type: "percent",
          pantry_fee: 0.1,
          roles: roles
        )
        [1, 1, 0.5, 0.4, 0, 0, 0.9, 0.8, 0.5, 0.4].each_with_index do |share, index|
          formula.parts.create!(type: types[index], rank: index, share: share)
        end
        admin_hhold = Household.create!(
          community: cmty,
          name: args.last_name
        )
        admin = User.create!(
          first_name: args.first_name,
          last_name: args.last_name,
          google_email: args.google_id,
          email: args.google_id,
          household: admin_hhold,
          mobile_phone: "5555551212"
        )
        admin.add_role(:admin)
        if args.populate.casecmp("y").zero?
          Utils::FakeData::MainGenerator.new(community: cmty, photos: true).generate
        end
      end
    end
  end


end
