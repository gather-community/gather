FactoryGirl.define do
  factory :reservation_protocoling, :class => 'Reservation::Protocoling' do
    resource
    protocol
  end
end
