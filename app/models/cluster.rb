# A group of related communities.
class Cluster < ActiveRecord::Base
  CLUSTER_BASED_MODELS = [Community, Invitation, Assignment, Signup, Meal, Meals::Cost,
    Meals::Formula, Meals::Message,
    People::EmergencyContact, People::Guardianship, People::Pet, Reservations::Protocoling,
    Reservations::Protocol, Reservations::GuidelineInclusion, Reservations::Resourcing,
    Reservations::SharedGuidelines, Reservations::Reservation, Reservations::Resource,
    Billing::Account, Billing::Statement, Billing::Transaction,
    User, Household]

  has_many :communities, inverse_of: :cluster, dependent: :destroy
end
