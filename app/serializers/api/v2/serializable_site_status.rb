module API
  module V2
    class SerializableSiteStatus < JSONAPI::Serializable::Resource
      type "site_statuses"

      attributes :vac_status, :publish, :status, :has_vacancies?

      has_one :site
    end
  end
end
