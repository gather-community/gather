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

Location.find_or_create_by!(name: "Touchstone Common House", abbrv: "TS CH")
Location.find_or_create_by!(name: "Touchstone Courtyard", abbrv: "TS Courtyard")
Location.find_or_create_by!(name: "Great Oak Common House", abbrv: "GO CH")
Location.find_or_create_by!(name: "Sunward Common House", abbrv: "SW CH")
