module Providers
  class AccreditedBodyCoursesReportService
    def execute(provider)
      get_course_data provider
    end

  private

    def get_course_data(provider)
      courses = provider.current_accredited_courses.map do |c|
        {
          provider_code: c.provider.provider_code,
          provider_name: c.provider.provider_name,
          course_code: c.course_code,
          course_name: c.name,
          study_mode: c.study_mode,
          program_type: c.program_type,
          qualification: c.qualification,
          content_status: c.content_status,
          sites: c.site_statuses.map do |ss|
            {
              site_code: ss.site.code,
              site_name: ss.site.location_name,
              site_status: ss.status,
              site_published: ss.published_on_ucas?,
              site_vacancies: ss.vac_status,
            }
          end,
        }
      end
      course_data = courses.select { |c| c[:sites].any? } # they aren't on "Find" or "Apply" if they have no sites
      course_data = flatten_sites(course_data)
      course_data.sort_by do |x|
        [
          x[:provider_name],
          x[:course_name],
          x[:program_type],
          x[:qualification],
          x[:site_name],
        ]
      end
    end

    def flatten_sites(courses)
      course_data = []
      courses.each do |c|
        c[:sites].each do |s|
          course_data << c.except(:sites).merge(s)
        end
      end
      course_data
    end

  end
end
