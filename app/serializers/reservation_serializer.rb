class ReservationSerializer < ActiveModel::Serializer
  attributes :id, :url, :title, :start, :end

  def url
    reservation_path(object)
  end

  def title
    object.name
  end

  def start
    object.starts_at
  end

  define_method("end") do
    object.ends_at
  end
end
