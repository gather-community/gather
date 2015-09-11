ts = Community.find_or_create_by!(name: 'Touchstone', abbrv: 'TS')
go = Community.find_or_create_by!(name: 'Great Oak', abbrv: 'GO')
sw = Community.find_or_create_by!(name: 'Sunward', abbrv: 'SW')

if Household.all.empty?
  h1 = Household.create!(name: "Buckland/Smith", unit_num: 1, community: ts)
  h2 = Household.create!(name: "Edmunds", unit_num: 2, community: ts)
  h3 = Household.create!(name: "Payne", unit_num: 2, community: ts)
  h4 = Household.create!(name: "Rutherford/Powell", unit_num: 501, community: go)
  h5 = Household.create!(name: "Gibson", unit_num: 502, community: go)
  h6 = Household.create!(name: "Brown/Walsh", unit_num: 502, community: go)
end

Location.find_or_create_by!(name: "Touchstone Common House") do |loc|
  loc.abbrv = "TS CH"
end
Location.find_or_create_by!(name: "Touchstone Courtyard") do |loc|
  loc.abbrv = "TS Courtyard"
end
Location.find_or_create_by!(name: "Great Oak Common House") do |loc|
  loc.abbrv = "GO CH"
end
Location.find_or_create_by!(name: "Sunward Common House") do |loc|
  loc.abbrv = "SW CH"
end

Formula.find_or_create_by(community_id: ts.id) do |f|
  f.effective_on = Date.civil(2015,1,1)
  f.senior_meat = 4
  f.adult_meat = 6
  f.teen_meat = 4
  f.big_kid_meat = 3
  f.little_kid_meat = 0
  f.senior_veg = 4
  f.adult_veg = 6
  f.teen_veg = 4
  f.big_kid_veg = 3
  f.little_kid_veg = 0
  f.pantry_fee = 0.5
  f.meal_calc_type = "fixed"
  f.pantry_calc_type = "fixed"
end

[go, sw].each do |community|
  Formula.find_or_create_by(community_id: community.id) do |f|
    f.effective_on = Date.civil(2015,1,1)
    f.senior_meat = nil
    f.adult_meat = 1
    f.teen_meat = 0.75
    f.big_kid_meat = 0.5
    f.little_kid_meat = 0
    f.senior_veg = nil
    f.adult_veg = 1
    f.teen_veg = 0.75
    f.big_kid_veg = 0.5
    f.little_kid_veg = 0
    f.pantry_fee = 0.1
    f.meal_calc_type = "share"
    f.pantry_calc_type = "share"
  end
end