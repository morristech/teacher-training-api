module API
  module V2
    class ProvidersController < API::V2::ApplicationController
      before_action :get_user, if: -> { params[:user_id].present? }
      before_action :build_recruitment_cycle
      before_action :build_provider, except: %i[index suggest]

      deserializable_resource :provider,
                              only: %i[update publish publishable],
                              class: API::V2::DeserializableProvider

      def index
        authorize Provider
        providers = policy_scope(@recruitment_cycle.providers)
                      .include_courses_counts
        providers = providers.where(id: @user.providers) if @user.present?

        render jsonapi: providers.in_order,
               fields: { providers: %i[provider_code provider_name courses
                                       recruitment_cycle_year] }
      end

      def show
        authorize @provider, :show?

        render jsonapi: @provider, include: params[:include]
      end

      def update
        authorize @provider, :update?

        update_enrichment
        update_accrediting_enrichment
        update_ucas_contacts
        update_ucas_preferences

        if @provider.valid?
          render jsonapi: @provider.reload, include: params[:include]
        else
          render jsonapi_errors: @provider.errors, status: :unprocessable_entity, include: params[:include]
        end
      end

      def publish
        authorize @provider, :publish?

        if @provider.publishable?
          @provider.publish_enrichment(@current_user)

          courses_synced?(@provider.syncable_courses)

          head :ok
        else
          render jsonapi_errors: @provider.errors, status: :unprocessable_entity
        end
      end

      def publishable
        authorize @provider, :publishable?

        if @provider.publishable?
          head :ok
        else
          render jsonapi_errors: @provider.errors, status: :unprocessable_entity
        end
      end

      def sync_courses_with_search_and_compare
        authorize @provider

        if !@recruitment_cycle.current?
          raise RuntimeError.new(
            "#{@provider} is not from the current recruitment cycle",
          )
        end

        courses_synced?(@provider.syncable_courses)

        head :ok
      end

      def suggest
        authorize Provider

        return render(status: :bad_request) if params[:query].nil? || params[:query].length < 3
        return render(status: :bad_request) unless begins_with_alphanumeric(params[:query])

        found_providers = policy_scope(@recruitment_cycle.providers)
          .search_by_code_or_name(params[:query])
          .limit(5)

        render(
          jsonapi: found_providers,
          class: { Provider: SerializableProviderSuggestion },
        )
      end

    private

      def begins_with_alphanumeric(string)
        string.match?(/^[[:alnum:]].*$/)
      end

      def build_recruitment_cycle
        @recruitment_cycle = RecruitmentCycle.find_by(
          year: params[:recruitment_cycle_year],
        ) || RecruitmentCycle.current_recruitment_cycle
      end

      def build_provider
        code = params.fetch(:code, params[:provider_code])
        @provider = @recruitment_cycle.providers
                      .includes(:latest_published_enrichment, :latest_enrichment)
                      .find_by!(
                        provider_code: code.upcase,
                      )
      end

      def get_user
        @user = User.find(params[:user_id])
      end

      def update_accrediting_enrichment
        return if accredited_bodies_params.values.none?

        enrichment = @provider.enrichments.find_or_initialize_draft(current_user)

        enrichment.accrediting_provider_enrichments =
          accredited_bodies_params["accredited_bodies"].map do |accredited_body|
            {
              UcasProviderCode: accredited_body["provider_code"],
              Description: accredited_body["description"],
            }
          end

        enrichment.save
      end

      def update_enrichment
        return unless enrichment_params.values.any?

        enrichment = @provider.enrichments.find_or_initialize_draft(current_user)
        enrichment.assign_attributes(enrichment_params)
        enrichment.status = "draft" if enrichment.rolled_over?

        enrichment.save
      end

      def update_ucas_contacts
        return if ucas_contact_params.blank?

        ucas_contact_params.keys.each do |type|
          contact = @provider.contacts.find_or_initialize_by(type: type.gsub(/_contact$/, ""))
          contact.assign_attributes(ucas_contact_params[type])
          contact.save
        end
      end

      def update_ucas_preferences
        return if ucas_preferences_params.blank?

        @provider.ucas_preferences.assign_attributes(ucas_preferences_params)
        @provider.ucas_preferences.save
      end

      def accredited_bodies_params
        params
          .fetch(:provider, {})
          .except(
            :train_with_us,
            :train_with_disability,
            :email,
            :telephone,
            :website,
            :address1,
            :address2,
            :address3,
            :address4,
            :postcode,
            :region_code,
            :admin_contact,
            :utt_contact,
            :web_link_contact,
            :fraud_contact,
            :finance_contact,
            :type_of_gt12,
            :gt12_contact,
            :application_alert_contact,
            :send_application_alerts,
          )
          .permit(accredited_bodies: %i[provider_code provider_name description])
      end

      def enrichment_params
        params
          .fetch(:provider, {})
          .except(
            :accredited_bodies,
            :admin_contact,
            :utt_contact,
            :web_link_contact,
            :fraud_contact,
            :finance_contact,
            :type_of_gt12,
            :gt12_contact,
            :application_alert_contact,
            :send_application_alerts,
          )
          .permit(
            :train_with_us,
            :train_with_disability,
            :email,
            :telephone,
            :website,
            :address1,
            :address2,
            :address3,
            :address4,
            :postcode,
            :region_code,
          )
      end

      def ucas_contact_params
        params
          .fetch(:provider, {})
          .except(
            :train_with_us,
            :train_with_disability,
            :email,
            :telephone,
            :website,
            :address1,
            :address2,
            :address3,
            :address4,
            :postcode,
            :region_code,
            :accredited_bodies,
            :type_of_gt12,
            :gt12_contact,
            :application_alert_contact,
            :send_application_alerts,
          )
          .permit(
            admin_contact: %w[name email telephone],
            utt_contact: %w[name email telephone],
            web_link_contact: %w[name email telephone],
            fraud_contact: %w[name email telephone],
            finance_contact: %w[name email telephone],
          )
      end

      def ucas_preferences_params
        params
          .fetch(:provider, {})
          .except(
            :accredited_bodies,
            :admin_contact,
            :utt_contact,
            :web_link_contact,
            :fraud_contact,
            :finance_contact,
            :train_with_us,
            :train_with_disability,
            :email,
            :telephone,
            :website,
            :address1,
            :address2,
            :address3,
            :address4,
            :postcode,
            :region_code,
          )
          .permit(
            :type_of_gt12,
            :gt12_contact,
            :application_alert_contact,
            :send_application_alerts,
          )
      end

      def courses_synced?(syncable_courses)
        SyncCoursesToFindJob.perform_later(*syncable_courses)
      end
    end
  end
end
