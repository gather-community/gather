ts = Community.find_or_create_by!(name: 'Touchstone')
go = Community.find_or_create_by!(name: 'Great Oak')
sw = Community.find_or_create_by!(name: 'Sunward')

if Household.all.empty?
  h1 = Household.create!(suffix: nil, unit_num: 1, community: ts)
  h2 = Household.create!(suffix: nil, unit_num: 2, community: ts)
  h3 = Household.create!(suffix: 'A', unit_num: 2, community: ts)
  h4 = Household.create!(suffix: nil, unit_num: 501, community: go)
  h5 = Household.create!(suffix: nil, unit_num: 502, community: go)
  h6 = Household.create!(suffix: 'A', unit_num: 502, community: go)
end

Location.find_or_create_by!(name: "Touchstone Common House", abbrv: "TS CH")
Location.find_or_create_by!(name: "Touchstone Courtyard", abbrv: "TS Courtyard")
Location.find_or_create_by!(name: "Great Oak Common House", abbrv: "GO CH")
Location.find_or_create_by!(name: "Sunward Common House", abbrv: "SW CH")
