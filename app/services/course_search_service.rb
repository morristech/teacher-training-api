class CourseSearchService
  def initialize(filter:, sort: nil, course_scope: Course)
    @filter = filter || {}
    @course_scope = course_scope
    @sort = Set.new(sort&.split(","))
  end

  class << self
    def call(**args)
      new(args).call
    end
  end

  def call
    scope = course_scope.findable

    if sort_by_provider_ascending?
      scope = scope.ascending_canonical_order
      scope = scope.select("provider.provider_name", "name")
    elsif sort_by_provider_descending?
      scope = scope.descending_canonical_order
      scope = scope.select("provider.provider_name", "name")
    elsif sort_by_distance?
      scope = scope.joins(sites_with_distance_from_origin)
      scope = scope.select("course.*, distance")
      scope = scope.order(:distance)
    end

    scope = scope.with_salary if funding_filter_salary?
    scope = scope.with_qualifications(qualifications) if qualifications.any?
    scope = scope.with_vacancies if has_vacancies?
    scope = scope.with_study_modes(study_types) if study_types.any?
    scope = scope.with_subjects(subject_codes) if subject_codes.any?
    scope = scope.with_provider_name(provider_name) if provider_name.present?
    scope = scope.with_send if send_courses_filter?

    # Default to 50 mile radius
    scope = scope.within(50, origin: origin) if locations_filter?
    scope = scope.with_funding_types(funding_types) if funding_types.any?

    scope.distinct
  end

  private_class_method :new

private

  def sites_with_distance_from_origin
    site_status = SiteStatus.arel_table
    sites = Site.arel_table
    providers = Provider.arel_table

    # Create virtual table with sites and site statuses
    sites_with_status = site_status.join(sites).on(site_status[:site_id].eq(sites[:id]))

    # Get provider information too
    sites_with_status = sites_with_status.join(providers).on(sites[:provider_id].eq(providers[:id]))

    # only want new and running sites
    new_and_running_sites = sites_with_status.where(site_status[:status].in(%w[new_status running]))

    # we only want sites that have been geocoded
    geocoded_new_and_running_sites = new_and_running_sites.where(sites[:latitude].not_eq(nil).and(sites[:longitude].not_eq(nil)))

    # only sites that have a locatable address
    # there are some sites with no address1 or postcode that cannot be
    # accurately geocoded. We don't want to return these as the closest site.
    # This should be removed once the data is fixed
    locatable_new_and_running_sites = geocoded_new_and_running_sites.where(sites[:address1].not_eq("").or(sites[:postcode].not_eq("")))

    # University sites
    university_sites = locatable_new_and_running_sites.dup.where(providers[:provider_type].eq("O"))

    # Non-university sites
    non_university_sites = locatable_new_and_running_sites.dup.where(providers[:provider_type].not_eq("O"))

    non_university_courses_with_nearest_site = non_university_sites.project(:course_id, Arel.sql("MIN#{Site.distance_sql(OpenStruct.new(lat: origin[0], lng: origin[1]))} as distance")).group(:course_id)

    university_courses_with_nearest_site = university_sites.project(:course_id, Arel.sql("MIN(#{Site.distance_sql(OpenStruct.new(lat: origin[0], lng: origin[1]))} - 5) as distance")).group(:course_id)

    courses_with_nearest_site = non_university_courses_with_nearest_site.union(university_courses_with_nearest_site)

    # form a temporary table with results
    distance_table = Arel::Nodes::TableAlias.new(
      Arel.sql(
        format("(%s)", courses_with_nearest_site.to_sql),
      ), "distances"
    )

    # grab courses table and join with the above result set
    # so distances from origin are now available
    # we can then sort by distance from the given origin
    courses_table = Course.arel_table
    courses_table.join(distance_table).on(
      courses_table[:id].eq(distance_table[:course_id]),
    ).join_sources
  end

  def locations_filter?
    filter.has_key?(:latitude) &&
      filter.has_key?(:longitude) &&
      filter.has_key?(:radius)
  end

  def sort_by_provider_ascending?
    sort == Set["name", "provider.provider_name"]
  end

  def sort_by_provider_descending?
    sort == Set["-name", "-provider.provider_name"]
  end

  def sort_by_distance?
    sort == Set["distance"]
  end

  def origin
    [filter[:latitude], filter[:longitude]]
  end

  attr_reader :sort, :filter, :course_scope

  def funding_filter_salary?
    filter[:funding] == "salary"
  end

  def qualifications
    return [] if filter[:qualification].blank?

    filter[:qualification].split(",")
  end

  def has_vacancies?
    filter[:has_vacancies].to_s.downcase == "true"
  end

  def study_types
    return [] if filter[:study_type].blank?

    filter[:study_type].split(",")
  end

  def funding_types
    return [] if filter[:funding_type].blank?

    filter[:funding_type].split(",")
  end

  def subject_codes
    return [] if filter[:subjects].blank?

    filter[:subjects].split(",")
  end

  def provider_name
    return [] if filter[:"provider.provider_name"].blank?

    filter[:"provider.provider_name"]
  end

  def send_courses_filter?
    filter[:send_courses].to_s.downcase == "true"
  end
end
