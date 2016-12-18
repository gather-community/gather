require 'csv'

namespace :db do
  task import_people: :environment do
    adults = []
    kids = []

    CSV.foreach("tmp/ts-people/people.csv") do |row|
      if row[1] == "adult"
        name = row[4]
        if name =~ /\A(.+?)\s*\((.+)\)\z/
          name = $1
          fam_members = $2.split(/,\s*/)
        else
          fam_members = []
        end

        if name == "Mary Ann Marquardt"
          first_name = "Mary Ann"
          last_name = "Marquardt"
        elsif name == "Mary Beth Wyllie"
          first_name = "Mary Beth"
          last_name = "Wyllie"
        else
          name_bits = name.split(" ")
          first_name = name_bits.first
          last_name = name_bits[1..-1].join(" ")
        end

        # Find matching user, complain if none
        u = User.joins(:household).where(households: {community_id: 1}, first_name: first_name, last_name: last_name).first
        raise "Can't find #{name}" unless u

        # Check unit number
        raise "Wrong unit number for #{name}" unless u.household.unit_num == row[2]

        vehicles = (row[8] || "").split(" and ")

        birthdate = row[7] ? Date.parse(row[7].split("-").reverse.join(" ") << " 0001") : nil

        adults << {
          img: row[0],
          user: u,
          name: name,
          first_name: first_name,
          last_name: last_name,
          fam_members: fam_members,
          garage: row[3].presence,
          birthdate: birthdate,
          vehicles: vehicles
        }

      else # children
        name = row[4]
        name_bits = name.split(" ")
        first_name = name_bits.first
        last_name = name_bits[1..-1].join(" ")

        birthdate = row[7] ? Date.strptime(row[7], "%m/%d/%y") : nil

        kids << {
          img: row[0],
          name: name,
          first_name: first_name,
          last_name: last_name,
          unit: row[2],
          birthdate: birthdate,
          guardians: []
        }

      end
    end

    adults.each do |adult|
      adult[:fam_members].each do |fm|
        ma = adults.select { |a| a[:first_name] == fm || a[:name] == fm }
        mk = kids.select { |a| a[:first_name] == fm || a[:name] == fm }
        matches = ma + mk

        if matches.size > 1
          raise "Found #{matches.map { |a| a[:name] }.inspect} for #{fm.inspect}"
        elsif matches.empty?
          raise "Found no matches for #{fm.inspect}"
        end

        mk.each do |kid|
          kid[:guardians] << adult[:user]
        end
      end
    end

    # If any children without parents, raise error.
    kids.each do |kid|
      if kid[:guardians].empty?
        raise "#{kid[:name]} has no guardians"
      end
    end

    households = {}

    adults.each do |adult|
      h = households[adult[:user].household] ||= {vehicles: [], garages: []}
      h[:vehicles].concat(adult[:vehicles])
      h[:garages] << adult[:garage] if adult[:garage]
    end

    households.each do |_, h|
      h[:garages].uniq!
      h[:vehicles].uniq!
    end

    puts households.values.join("\n")
  end
end
