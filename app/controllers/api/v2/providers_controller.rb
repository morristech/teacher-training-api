module API
  module V2
    class ProvidersController < API::V2::ApplicationController
      before_action :get_user, if: -> { params[:user_id].present? }

      def index
        authorize Provider
        providers = policy_scope(Provider).include_courses_counts
        providers = providers.where(id: @user.providers) if @user.present?

        render jsonapi: providers.in_order, fields: { providers: %i[provider_code provider_name courses] }
      end

      def show
        provider = Provider.includes(:latest_published_enrichment).find_by!(provider_code: params[:code].upcase)
        authorize provider, :show?

        render jsonapi: provider, include: params[:include]
      end

      def sync_courses_with_search_and_compare
        provider = Provider.find_by!(provider_code: params[:code].upcase)
        authorize provider
        syncable_courses = provider.syncable_courses
        response = SearchAndCompareAPIService::Request.sync(
          syncable_courses
        )
        if response
          head :ok
        else
          raise RuntimeError.new(
            'error received when syncing courses with search and compare'
          )
        end
      end

    private

      def get_user
        @user = User.find(params[:user_id])
      end
    end
  end
end
