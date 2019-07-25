require "rails_helper"

describe 'PATCH /providers/:provider_code' do
  let(:jsonapi_renderer) { JSONAPI::Serializable::Renderer.new }
  let(:request_path) do
    "/api/v2/recruitment_cycles/#{recruitment_cycle.year}" +
      "/providers/#{provider.provider_code}"
  end

  def perform_request(provider)
    jsonapi_data = jsonapi_renderer.render(
      provider,
      class: {
        Provider: API::V2::SerializableProvider
      }
    )

    jsonapi_data.dig(:data, :attributes).slice!(*permitted_params)

    if provider.enrichments.first.present?
      enrichment_data = provider.enrichments.first.slice(*permitted_params)
      jsonapi_data.dig(:data, :attributes).merge!(enrichment_data)
    end

    patch request_path,
          headers: { 'HTTP_AUTHORIZATION' => credentials },
          params: {
            _jsonapi: jsonapi_data,
            include: 'latest_enrichment'
          }
  end

  let(:recruitment_cycle) { find_or_create :recruitment_cycle }
  let(:organisation) { create :organisation }
  let(:provider)     do
    create :provider,
           organisations: [organisation],
           recruitment_cycle: recruitment_cycle
  end
  let(:user)         { create :user, organisations: [organisation] }
  let(:payload)      { { email: user.email } }
  let(:token)        { build_jwt :apiv2, payload: payload }
  let(:enrichment)   { build(:provider_enrichment) }
  let(:update_enrichment) { build :provider_enrichment, **updated_attributes }
  # we need an unsaved provider to add the enrichment to (so that it isn't
  # persisted)
  let(:update_provider) { provider.dup.tap { |p| p.enrichments << update_enrichment } }

  let(:credentials) do
    ActionController::HttpAuthentication::Token.encode_credentials(token)
  end

  let(:updated_attributes) do
    {
      email: 'email_address',
      website: 'url',
      address1: 'number',
      address2: 'street',
      address3: 'town',
      address4: 'county',
      postcode: 'sw1p 3bt',
      region_code: 'london',
      telephone: '01234 567890',
      train_with_us: 'train with us',
      train_with_disability: 'train with disability'
    }
  end
  let(:permitted_params) do
    %i[
      email
      website
      address1
      address2
      address3
      address4
      postcode
      region_code
      telephone
      train_with_us
      train_with_disability
    ]
  end

  describe 'with unpermitted attributes on provider object' do
    shared_examples 'does not allow assignment' do |attribute, value|
      it "doesn't permit #{attribute}" do
        update_provider = build(:provider, attribute => value)
        update_provider.id = provider.id
        perform_request(provider)
        expect(provider.reload.send(attribute)).not_to eq(value)
      end
    end

    include_examples 'does not allow assignment', :id,                   9999
    include_examples 'does not allow assignment', :provider_name,        'provider name'
    include_examples 'does not allow assignment', :scheme_member,        'scheme member'
    include_examples 'does not allow assignment', :contact_name,         'contact name'
    include_examples 'does not allow assignment', :year_code,            'year code'
    include_examples 'does not allow assignment', :provider_code,        'provider code'
    include_examples 'does not allow assignment', :provider_type,        :lead_school
    include_examples 'does not allow assignment', :scitt,                'scitt'
    include_examples 'does not allow assignment', :url,                  'url'
    include_examples 'does not allow assignment', :created_at,           Time.now
    include_examples 'does not allow assignment', :updated_at,           Time.now
    include_examples 'does not allow assignment', :accrediting_provider, :accredited_body
    include_examples 'does not allow assignment', :last_published_at,    Time.now
    include_examples 'does not allow assignment', :changed_at,           Time.now
    include_examples 'does not allow assignment', :recruitment_cycle_id, 9999

    context 'attributes from other models' do
      let(:provider2) { create(:provider, courses: [course2], sites: [site]) }
      let(:course2) { build(:course) }
      let(:site) { build(:site) }

      before do
        provider2.id = provider.id
        perform_request(provider2)
      end

      subject { provider.reload }

      context 'with a course' do
        its(:courses) { should_not include(course2) }
      end

      context 'with sites' do
        its(:sites) { should_not include(site) }
      end
    end

    context 'provider has no enrichments' do
      it "creates a draft enrichment for the provider" do
        expect {
          perform_request update_provider
        }.to(change {
               provider.reload.enrichments.count
             }.from(0).to(1))

        draft_enrichment = provider.enrichments.draft.first

        expect(draft_enrichment.attributes.slice(*updated_attributes.keys.map(&:to_s)))
          .to include(updated_attributes.stringify_keys)
      end

      it "change content status" do
        expect {
          perform_request update_provider
        }.to(change { provider.reload.content_status }.from(:empty).to(:draft))
      end

      context "with no attributes to update" do
        let(:updated_attributes) do
          {
            email: nil,
            website: nil,
            address1: nil,
            address2: nil,
            address3: nil,
            address4: nil,
            postcode: nil,
            region_code: nil,
            telephone: nil,
            train_with_us: nil,
            train_with_disability: nil
          }
        end

        it "doesn't create a draft provider enrichment" do
          expect {
            perform_request update_provider
          }.to_not(change { provider.reload.enrichments.count })
        end
      end

      context "with empty attributes" do
        let(:permitted_params) { [] }

        it "doesn't create a draft enrichment" do
          expect {
            perform_request update_provider
          }.to_not(change { provider.reload.enrichments.count })
        end

        it "doesn't change content status" do
          expect {
            perform_request update_provider
          }.to_not(change { provider.reload.content_status })
        end
      end

      it 'returns ok' do
        perform_request update_provider

        expect(response).to be_ok
      end

      it 'returns the updated provider with the enrichment included' do
        perform_request update_provider
        json_response = JSON.parse(response.body)["included"].first

        expect(json_response).to have_id(provider.reload.enrichments.first.id.to_s)
        expect(json_response).to have_type('provider_enrichment')
        expect(json_response).to have_attribute(:email).with_value('email_address')
        expect(json_response).to have_attribute(:website).with_value('url')
        expect(json_response).to have_attribute(:address1).with_value('number')
        expect(json_response).to have_attribute(:address2).with_value('street')
        expect(json_response).to have_attribute(:address3).with_value('town')
        expect(json_response).to have_attribute(:address4).with_value('county')
        expect(json_response).to have_attribute(:postcode).with_value('sw1p 3bt')
        expect(json_response).to have_attribute(:region_code).with_value('london')
        expect(json_response).to have_attribute(:telephone).with_value('01234 567890')
        expect(json_response).to have_attribute(:train_with_us).with_value('train with us')
        expect(json_response).to have_attribute(:train_with_disability).with_value('train with disability')
        expect(json_response).to have_attribute(:status).with_value('draft')
      end


  context 'provider has a draft enrichment' do
    let(:enrichment) { build(:provider_enrichment) }
    let(:provider) { create :provider,
                              enrichments: [enrichment],
                              organisations: [organisation],
                            recruitment_cycle: recruitment_cycle }

    it "updates the provider's draft enrichment" do
      expect {
        perform_request update_provider
      }.not_to(
        change { provider.enrichments.reload.count }
      )

      draft_enrichment = provider.enrichments.draft.first
      expect(draft_enrichment.attributes.slice(*updated_attributes.keys.map(&:to_s)))
        .to include(updated_attributes.stringify_keys)
    end

    it "doesn't change content status" do
      expect {
        perform_request update_provider
      }.to_not(change { provider.reload.content_status })
    end

    context "with invalid data" do
      let(:updated_attributes) do
        {
          about_course: Faker::Lorem.sentence(1000),
          fee_details: Faker::Lorem.sentence(1000),
          fee_international: 200_000,
          fee_uk_eu: 200_000,
          financial_support: Faker::Lorem.sentence(1000),
          how_school_placements_work: Faker::Lorem.sentence(1000),
          interview_process: Faker::Lorem.sentence(1000),
          other_requirements: Faker::Lorem.sentence(1000),
          personal_qualities: Faker::Lorem.sentence(1000),
          qualifications: Faker::Lorem.sentence(1000),
          salary_details: Faker::Lorem.sentence(1000)
        }
      end

      subject { JSON.parse(response.body)["errors"].map { |e| e["title"] } }

      it "returns validation errors" do
        perform_request update_course

        expect("Invalid about_course".in?(subject)).to eq(true)
        expect("Invalid interview_process".in?(subject)).to eq(true)
        expect("Invalid how_school_placements_work".in?(subject)).to eq(true)
        expect("Invalid qualifications".in?(subject)).to eq(true)
        expect("Invalid fee_details".in?(subject)).to eq(true)
        expect("Invalid financial_support".in?(subject)).to eq(true)
      end
    end

  #   context "with nil data" do
  #     let(:updated_attributes) do
  #       {
  #         about_course: "",
  #         fee_details: "",
  #         fee_international: 0,
  #         fee_uk_eu: 0,
  #         financial_support: "",
  #         how_school_placements_work: "",
  #         interview_process: "",
  #         other_requirements: "",
  #         personal_qualities: "",
  #         qualifications: "",
  #         salary_details: ""
  #       }
  #     end
  #
  #     it "returns ok" do
  #       perform_request update_course
  #
  #       expect(response).to be_ok
  #     end
  #
  #     it "doesn't change content status" do
  #       expect {
  #         perform_request update_course
  #       }.to_not(change { course.reload.content_status })
  #     end
  #   end
  # end
  #
  # context 'course has only a published enrichment' do
  #   let(:enrichment) { build :course_enrichment, :published }
  #   let(:course) do
  #     create :course, provider: provider, enrichments: [enrichment]
  #   end
  #
  #   it "creates a draft enrichment for the course" do
  #     expect { perform_request update_course }
  #       .to(
  #         change { course.enrichments.reload.draft.count }
  #           .from(0).to(1)
  #       )
  #
  #     draft_enrichment = course.enrichments.draft.first
  #     expect(draft_enrichment.attributes.slice(*updated_attributes.keys.map(&:to_s)))
  #       .to include(updated_attributes.stringify_keys)
  #   end
  #
  #   it do
  #     expect { perform_request update_course }
  #     .to(
  #       change { course.enrichments.reload.count }
  #         .from(1).to(2)
  #     )
  #   end
  #
  #   it "change content status" do
  #     expect {
  #       perform_request update_course
  #     }.to(change { course.reload.content_status }.from(:published).to(:published_with_unpublished_changes))
  #   end
  #
  #   context "with invalid data" do
  #     let(:updated_attributes) do
  #       { about_course: Faker::Lorem.sentence(1000) }
  #     end
  #
  #     subject { JSON.parse(response.body)["errors"].map { |e| e["title"] } }
  #
  #     it "returns validation errors" do
  #       perform_request update_course
  #
  #       expect("Invalid enrichments".in?(subject)).to eq(false)
  #       expect("Invalid about_course".in?(subject)).to eq(true)
  #     end
  #   end
  # end
  #
  # context 'course has a rolled-over enrichment' do
  #   let(:enrichment) { build :course_enrichment, :rolled_over }
  #   let(:course) do
  #     create :course, provider: provider, enrichments: [enrichment]
  #   end
  #
  #   it "updates the course's draft enrichment" do
  #     expect {
  #       perform_request update_course
  #     }.not_to(
  #       change { course.enrichments.reload.count }
  #     )
  #
  #     draft_enrichment = course.enrichments.draft.first
  #     expect(draft_enrichment.attributes.slice(*updated_attributes.keys.map(&:to_s)))
  #       .to include(updated_attributes.stringify_keys)
  #   end
  #
  #   it "changes the content status to draft" do
  #     expect {
  #       perform_request update_course
  #     }.to(
  #       change { course.reload.content_status }
  #         .from(:rolled_over).to(:draft)
  #     )
  #   end
  #
  #   context "with invalid data" do
  #     let(:updated_attributes) do
  #       {
  #         about_course: Faker::Lorem.sentence(1000),
  #         fee_details: Faker::Lorem.sentence(1000),
  #         fee_international: 200_000,
  #         fee_uk_eu: 200_000,
  #         financial_support: Faker::Lorem.sentence(1000),
  #         how_school_placements_work: Faker::Lorem.sentence(1000),
  #         interview_process: Faker::Lorem.sentence(1000),
  #         other_requirements: Faker::Lorem.sentence(1000),
  #         personal_qualities: Faker::Lorem.sentence(1000),
  #         qualifications: Faker::Lorem.sentence(1000),
  #         salary_details: Faker::Lorem.sentence(1000)
  #       }
  #     end
  #
  #     subject { JSON.parse(response.body)["errors"].map { |e| e["title"] } }
  #
  #     it "returns validation errors" do
  #       perform_request update_course
  #
  #       expect("Invalid about_course".in?(subject)).to eq(true)
  #       expect("Invalid interview_process".in?(subject)).to eq(true)
  #       expect("Invalid how_school_placements_work".in?(subject)).to eq(true)
  #       expect("Invalid qualifications".in?(subject)).to eq(true)
  #       expect("Invalid fee_details".in?(subject)).to eq(true)
  #       expect("Invalid financial_support".in?(subject)).to eq(true)
  #     end
  #
  #     it "doesn't change content status" do
  #       expect {
  #         perform_request update_course
  #       }.to_not(change { course.reload.content_status })
  #     end
  #   end
  #
  #   context "with nil data" do
  #     let(:updated_attributes) do
  #       {
  #         about_course: "",
  #         fee_details: "",
  #         fee_international: 0,
  #         fee_uk_eu: 0,
  #         financial_support: "",
  #         how_school_placements_work: "",
  #         interview_process: "",
  #         other_requirements: "",
  #         personal_qualities: "",
  #         qualifications: "",
  #         salary_details: ""
  #       }
  #     end
  #
  #     it "returns ok" do
  #       perform_request update_course
  #
  #       expect(response).to be_ok
  #     end
  #
  #     it "changes the content status to draft" do
  #       expect {
  #         perform_request update_course
  #       }.to(
  #         change { course.reload.content_status }
  #           .from(:rolled_over).to(:draft)
  #       )
  #     end
  #   end
  # end
  #
  # describe 'from published to draft' do
  #   shared_examples 'only one attribute has changed' do |attribute_key, attribute_value, jsonapi_serialized_name|
  #     describe 'a subsequent draft enrichment is added' do
  #       let(:updated_attributes) do
  #         attribute = {}
  #         attribute[attribute_key] = attribute_value
  #         attribute
  #       end
  #
  #       let(:permitted_params) {
  #         if jsonapi_serialized_name.blank?
  #           [attribute_key]
  #         else
  #           [jsonapi_serialized_name]
  #         end
  #       }
  #
  #       before do
  #         perform_request update_course
  #       end
  #
  #       subject {
  #         course.reload
  #       }
  #
  #       its(:content_status) { should eq :published_with_unpublished_changes }
  #
  #       it "set #{attribute_key}" do
  #         expect(subject.enrichments.draft.first[attribute_key]).to eq(attribute_value)
  #       end
  #
  #       enrichments_attributes_key = %i[
  #         about_course
  #         fee_details
  #         fee_international
  #         fee_uk_eu
  #         financial_support
  #         how_school_placements_work
  #         interview_process
  #         other_requirements
  #         personal_qualities
  #         qualifications
  #         salary_details
  #       ].freeze
  #
  #       published_enrichment_attributes = (enrichments_attributes_key.filter { |x| x != attribute_key }).freeze
  #
  #       published_enrichment_attributes.each do |published_enrichment_attribute|
  #         it "set #{published_enrichment_attribute} using published enrichment" do
  #           expect(subject.enrichments.draft.first[published_enrichment_attribute]).to eq(original_enrichment[published_enrichment_attribute])
  #         end
  #       end
        end
      end
  #
  #   let(:original_enrichment) { build :course_enrichment, :published }
  #   let(:course) do
  #     create :course, provider: provider, enrichments: [original_enrichment]
  #   end
  #
  #   include_examples 'only one attribute has changed', :fee_details, 'changed fee_details'
  #   include_examples 'only one attribute has changed', :fee_international, 666
  #   include_examples 'only one attribute has changed', :fee_uk_eu, 999
  #   include_examples 'only one attribute has changed', :financial_support, 'changed financial_support'
  #   include_examples 'only one attribute has changed', :how_school_placements_work, 'changed how_school_placements_work'
  #   include_examples 'only one attribute has changed', :interview_process, 'changed interview_process'
  #   include_examples 'only one attribute has changed', :other_requirements, 'changed other_requirements'
  #   include_examples 'only one attribute has changed', :personal_qualities, 'changed personal_qualities'
  #   include_examples 'only one attribute has changed', :qualifications, 'changed qualifications', :required_qualifications
  #   include_examples 'only one attribute has changed', :salary_details, 'changed salary_details'
  end
end
