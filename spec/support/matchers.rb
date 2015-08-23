RSpec::Matchers.define :be_able_to do |op, target|
  match do |user|
    Ability.new(user).can?(op.to_sym, target)
  end
end

RSpec::Matchers.define :be_able_to_index_by_sql do |target|
  match do |user|
    target.class.accessible_by(Ability.new(user)).include?(target)
  end
end
