module Csv
  class UserDecorator < ::UserDecorator
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

    def vehicles
      adult? && household.vehicles.any? ? household.vehicles.map(&:to_s).join("; ") : nil
    end

    def unit_num
      household.unit_num
    end

    def garage_nums
      household.garage_nums
    end

    private

    def l(date_or_time)
      return nil if date_or_time.nil?
      I18n.l(date_or_time, format: :csv_full)
    end

    def bool(val)
      I18n.t("common.#{val ? 'true' : 'false'}")
    end
  end
end
