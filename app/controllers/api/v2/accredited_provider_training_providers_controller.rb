module API
  module V2
    class AccreditedProviderTrainingProvidersController < API::V2::ApplicationController
      before_action :build_recruitment_cycle
      before_action :build_provider

      def index
        authorize @provider, :can_list_training_providers?
        providers = if params[:filter]
                      course_scope = Course.where(
                        provider: training_providers,
                        accrediting_provider_code: @provider.provider_code,
                      )
                      if negated_params?
                        excluded_training_provider_ids =
                                                  CourseSearchService
                                                   .call(filter: negated_filters, course_scope: course_scope)
                                                   .pluck(:provider_id)
                        eligible_training_provider_ids = training_providers.map(&:id) - excluded_training_provider_ids
                      else
                        # exclude_negated_params if negated_params?
                        eligible_training_provider_ids = CourseSearchService
                                                           .call(filter: params[:filter], course_scope: course_scope)
                                                           .pluck(:provider_id)
                      end
                      training_providers.where(id: eligible_training_provider_ids).order(:provider_name)
                    else
                      training_providers
                    end

        # providers = training_providers unless params[:filter]
        # if params[:filter]
        #   course_scope = Course.where(
        #     provider: training_providers,
        #     accrediting_provider_code: @provider.provider_code,
        #   )
        #   if negated_params?
        #     excluded_training_provider_ids =
        #                               CourseSearchService
        #                                .call(filter: negated_filter_params, course_scope: course_scope)
        #                                .pluck(:provider_id)
        #     exclude_negated_params
        #   end
        #
        #   eligible_training_provider_ids =
        #     if params[:filter]
        #       CourseSearchService
        #          .call(filter: params[:filter], course_scope: course_scope)
        #          .pluck(:provider_id)
        #       else
        #         training_providers.pluck(:provider_id)
        #     end
        #     eligible_training_provider_ids = eligible_training_provider_ids - excluded_training_provider_ids
        #
        #   training_providers.where(id: eligible_training_provider_ids).order(:provider_name)
        # else
        #   training_providers
        # end

        render jsonapi: providers, include: params[:include]
      end

    private

      def negated_params?
        params[:filter].each_value do |value|
          return true if !!value.match(/^-/)
        end
        false
      end

      def negated_filters
        #new hash only minus onces and remove "-" form the value
        # Hash.new do |hash, key|
        #   params[:filter].each do |filter, value|
        #     hash[filter] = value[1..-1] if !!value.match(/^-/)
        #   end
        # end

        # params[:filter][:subjects] = params[:filter][:subjects][1..-1] if !!params[:filter][:subjects].match(/^-/)
        filters = params[:filter].reject { |filter, value| !!!value.match(/^-/) }
        filters.each { |filter, value| filters[filter] = value[1..-1] }
      end

      def exclude_negated_params
        params[:filter].reject { |filter, value| !!value.match(/^-/) }
      end
      #
      # def filter_params
      #   params[:filter].each do |filter, value|
      #     params[:filter][filter] = value[1..-1] if !!value.match(/^-/)
      #   end
      # end

      def build_recruitment_cycle
        @recruitment_cycle = RecruitmentCycle.find_by(
          year: params[:recruitment_cycle_year],
        ) || RecruitmentCycle.current_recruitment_cycle
      end

      def build_provider
        @provider = @recruitment_cycle.providers.find_by!(
          provider_code: params[:provider_code].upcase,
        )
      end

      def training_providers
        @provider.training_providers
      end
    end
  end
end
