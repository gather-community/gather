FactoryGirl.define do
  factory :reservation, class: "Reservation::Reservation" do
    name "Fun times"
    resource
    user
    starts_at "2016-03-19 21:56:11"
    ends_at "2016-03-19 21:56:11"
    kind nil
  end
end
