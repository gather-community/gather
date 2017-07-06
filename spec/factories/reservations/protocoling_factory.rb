FactoryGirl.define do
  factory :reservation_protocoling, :class => 'Reservations::Protocoling' do
    resource
    protocol
  end
end
