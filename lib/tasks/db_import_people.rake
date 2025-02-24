# frozen_string_literal: true

require "csv"

namespace :db do
  task import_people: :environment do
    adults = []
    kids = []
    @errors = false

    def print_error(msg)
      puts(msg)
      @errors = true
      true
    end

    CSV.foreach("tmp/go-people/member_directory.csv", headers: true, header_converters: :symbol) do |row|
      photo = begin
        File.open("tmp/go-people/#{row[:photo_path]}", "r")
      rescue StandardError
        nil
      end

      first_name = row[:first_name]
      last_name = row[:last_name]
      birthdate = row[:bday] ? Date.strptime(row[:bday], "%m/%d/%Y") : nil

      if row[:adult_child] == "adult"
        # Find matching user, complain if none
        u = User.joins(:household).where(households: {community_id: 2}, first_name: first_name,
                                         last_name: last_name).first
        print_error("Can't find adult #{first_name} #{last_name}") && next unless u

        old_unit = u.household.unit_num.to_s.sub(/^5/, "").to_i
        new_unit = row[:unit].to_i

        if old_unit != 0 && old_unit != new_unit
          # Check unit number
          print_error("Wrong unit number for #{first_name} #{last_name} (#{old_unit} vs #{new_unit})") && next
        end

        vehicles = (row[:vehicles] || "").split(" and ")
        vehicles.map! do |str|
          str = str.split(/\s*,\s*/)
          str[0] = str[0].split(" ")
          str.flatten.each { |s| s[0] = s[0].capitalize }
          {make: str[0][0], model: str[0][1..-1].join(" "), color: str[1]}
        end

        adults << {
          photo: photo,
          user: u,
          first_name: first_name,
          last_name: last_name,
          garage: row[:garage].presence,
          birthdate: birthdate,
          vehicles: vehicles
        }
      else
        guardians = (row[:parents] || "").split(/\s*;\s*/).map do |parent_name|
          fn, ln = parent_name.split(" ")
          parent = User.find_by(first_name: fn, last_name: ln)
          print_error("Couldn't find parent '#{parent_name}'") && next unless parent

          parent
        end.compact

        print_error("#{first_name} #{last_name} has no guardians") && next if guardians.empty?

        kids << {
          photo: photo,
          first_name: first_name,
          last_name: last_name,
          unit: new_unit,
          birthdate: birthdate,
          guardians: guardians,
          household: guardians.first.household
        }
      end
    end

    households = {}

    # Add vehicles and garages to household
    adults.each do |adult|
      h = households[adult[:user].household] ||= {vehicles: [], garages: []}
      h[:vehicles].concat(adult[:vehicles])
      h[:garages] << adult[:garage] if adult[:garage]
    end

    households.each do |_, h|
      h[:garages].uniq!
      h[:vehicles].uniq!
    end

    raise "errors were raised" if @errors

    User.transaction do
      adults.each do |user|
        attribs = %i[first_name last_name birthdate]
        attribs << :photo if user[:user].photo.blank?
        user[:user].update_attributes!(user.slice(*attribs))
      end
      kids.each do |kid|
        if User.find_by(kid.slice(:first_name, :last_name)).nil?
          User.create!(kid.slice(:first_name, :last_name, :birthdate, :guardians, :photo, :household)
            .merge(child: true, full_access: false))
        end
      end
      households.each do |household, attribs|
        household.update_attributes!(
          garage_nums: attribs[:garages].join(", ")
        )
        attribs[:vehicles].each do |v|
          household.vehicles.find_or_create_by!(v)
        end
      end
    rescue ActiveRecord::RecordInvalid
      p($!.record)
      p($!.record.errors)
    end
  end
end
