require 'csv'

namespace :db do
  task import_people: :environment do
    adults = []
    kids = []

    CSV.foreach("tmp/ts-people/people.csv") do |row|
      img_path = row[0].blank? ? nil : "tmp/ts-people/#{row[0]}"
      photo = img_path ? File.open(img_path, "r") : nil

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
        vehicles.map! do |str|
          str = str.split(/\s*,\s*/)
          str[0] = str[0].split(" ")
          str.flatten.each { |s| s[0] = s[0].capitalize }
          {make: str[0][0], model: str[0][1..-1].join(" "), color: str[1]}
        end

        birthdate = row[7] ? Date.parse(row[7].split("-").reverse.join(" ") << " 0001") : nil

        adults << {
          photo: photo,
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
          photo: photo,
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

    User.transaction do
      begin
        adults.each do |user|
          attribs = [:first_name, :last_name, :birthdate]
          attribs << :photo unless user[:user].photo.present?
          user[:user].update_attributes!(user.slice(*attribs))
        end
        kids.each do |kid|
          if User.find_by(kid.slice(:first_name, :last_name)).nil?
            User.create!(kid.slice(:first_name, :last_name, :birthdate, :guardians, :photo).
              merge(household: kid[:guardians].first.household, child: true))
          end
        end
        households.each do |household, attribs|
          household.update_attributes!(garage_nums: attribs[:garages].join(", "))
          attribs[:vehicles].each do |v|
            household.vehicles.find_or_create_by!(v)
          end
        end
      rescue ActiveRecord::RecordInvalid
        p $!.record
        p $!.record.errors
      end
    end
  end
end
