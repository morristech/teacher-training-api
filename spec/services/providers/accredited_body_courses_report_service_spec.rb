require "rails_helper"

describe Providers::AccreditedBodyCoursesReportService do
  let(:service) { described_class.new() }

  describe "#execute" do
    it "should return some things" do
      provider = instance_double(Provider)
      input_data = ["raa"]
      allow(provider).to receive(:current_accredited_courses)
        .and_return(input_data)
      returned_data = service.execute(provider)
      expect(returned_data.length).to eq(1)
    end
  end
end
