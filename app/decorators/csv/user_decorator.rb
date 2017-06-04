module Csv
  class UserDecorator < ::UserDecorator
    include Utils
    delegate_all

    def birthdate
      object.birthday.str(formats: [:csv_month_day, :csv_full])
    end

    def joined_on
      l(object.joined_on)
    end

    def child
      bool(object.child?)
    end
  end
end
