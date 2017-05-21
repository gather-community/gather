namespace :db do
  task :fake_account_data, [:household_ids] => :environment do |t, args|
    raise "Please specify household_ids, separated by the | character" unless args.household_ids.present?

    Billing::Account.update_all("last_statement_id = NULL")
    [Billing::Transaction, Billing::Statement, Billing::Account].each{ |k| k.delete_all }

    households = Household.active.shuffle[0...20] | Household.find(args.household_ids.split("|"))
    households.each do |household|
      communities = [household.community] | Community.all.shuffle[0...rand(4)]
      communities.each do |community|
        account = household.accounts.create!(community: community)
        months = rand(7)
        prev_balance = nil
        months.times do |i|
          Timecop.freeze(Time.current - (months - i).months) do
            # Charges
            charges = rand(8)
            charges.times do
              Timecop.freeze(Time.current + rand(28).days) do
                account.transactions.create!(code: "meal", description: Faker::Lorem.sentence(4)[0..-2],
                  incurred_on: Date.today, amount: (rand(1000).to_f + 50) / 100)
              end
            end

            # Payment
            has_balance = !(prev_balance.nil? || prev_balance == 0)
            if has_balance && prev_balance > 0
              Timecop.freeze(Time.current + rand(28).days) do
                account.transactions.create!(code: "payment", description: "Check ##{rand(10000) + 100}",
                  incurred_on: Date.today,
                  amount: -(rand(10) < 1 ? prev_balance - 5 + rand(10) : prev_balance))
              end
            end

            # Reimbursement
            if rand(20) < 1
              Timecop.freeze(Time.current + rand(28).days) do
                account.transactions.create!(code: "reimb", description: Faker::Lorem.sentence(4)[0..-2],
                  incurred_on: Date.today,
                  amount: -(rand(10000).to_f + 5000) / 100)
              end
            end

            # Statement (don't run in last month)
            if (has_balance || charges > 0) && i < months - 1
              Timecop.freeze(Time.current + 30.days) do
                statement = Billing::Statement.new(account: account, prev_balance: prev_balance || 0)
                statement.populate!
                prev_balance = statement.total_due
              end
            end
          end
        end
      end
    end
  end
end
