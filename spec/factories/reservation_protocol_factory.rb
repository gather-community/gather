FactoryGirl.define do
  factory :reservation_protocol, class: "Reservation::Protocol" do
    resource
    kinds "personal"
    max_length_minutes 120
    fixed_start_time "9:00"
    fixed_end_time "11:00"
    max_lead_days 14
  end
end
