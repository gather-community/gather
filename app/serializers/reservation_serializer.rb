class ReservationSerializer < ActiveModel::Serializer
  attributes :id, :url, :title, :start, :end, :editable, :className

  def url
    if object.meal && MealPolicy.new(scope, object.meal).show?
      meal_path(object.meal)
    else
      reservation_path(object)
    end
  end

  def title
    object.name
  end

  def start
    object.starts_at
  end

  # end is a reserved word
  define_method("end") do
    object.ends_at
  end

  def editable
    # scope == current_user
    Reservation::ReservationPolicy.new(scope, object).edit?
  end

  def className
    if object.meal
      "has-meal"
    elsif object.reserver == scope
      "own-reservation"
    else
      ""
    end
  end
end
