module API
  module V3
    class CourseSearchesController < API::V3::ApplicationController
      def index
        course_scope = CourseSearch.call(filter: params[:filter], recruitment_cycle_year: params[:recruitment_cycle_year])
        render jsonapi: paginate(course_scope)
      end
    end
  end
end
