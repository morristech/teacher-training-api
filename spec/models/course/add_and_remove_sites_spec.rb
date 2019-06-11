RSpec.describe Course, type: :model do
  describe "adding and removing sites on a course" do
    let(:new_site) { build(:site, code: 'A') }
    let(:existing_site) { build(:site, code: 'B') }

    let(:provider) { build(:provider, sites: [new_site, existing_site]) }

    let(:new_site_status) { subject.site_statuses.find_by!(site: new_site) }

    let(:course) { create(:course, provider: provider, site_statuses: [existing_site_status]) }
    subject { course }

    context "for running course" do
      let(:existing_site_status) { create(:site_status, :running, :published, site: existing_site) }

      it "suspends the site when an existing site is removed" do
        expect { subject.remove_site!(site: existing_site) }.
          to change { existing_site_status.reload.status }.from("running").to("suspended")
      end

      it "adds a new site status and sets it to running when a new site is added" do
        expect { subject.add_site!(site: new_site) }.to change { subject.reload.site_statuses.size }.
          from(1).to(2)
        expect(new_site_status.status).to eq("running")
      end
    end

    context "for new course" do
      let(:existing_site_status) { create(:site_status, :new, site: existing_site) }

      it "sets the site to new when a new site is added" do
        expect { subject.add_site!(site: new_site) }.to change { subject.reload.site_statuses.size }.
          from(1).to(2)
        expect(new_site_status.status).to eq("new_status")
      end

      it "keeps the site status as new when an existing site is added" do
        expect { subject.add_site!(site: existing_site) }.
          to_not change { existing_site_status.reload.status }.from("new_status")
      end

      it "removes the site status when an existing site is removed" do
        expect { subject.remove_site!(site: existing_site) }.to change { subject.reload.site_statuses.size }.
          from(1).to(0)
      end
    end

    context "for suspended course" do
      let(:existing_site_status) { create(:site_status, :suspended, site: existing_site) }

      it "sets the site to running when a new site is added" do
        expect { subject.add_site!(site: new_site) }.to change { subject.reload.site_statuses.size }.
          from(1).to(2)
        expect(new_site_status.status).to eq("running")
      end

      it "sets the site to running when an existing site is added" do
        expect { subject.add_site!(site: existing_site) }.
          to change { existing_site_status.reload.status }.from("suspended").to("running")
      end
    end

    context "for course without any training locations" do
      subject { create(:course, site_statuses: []) }

      it "sets the site to new when a new site is added" do
        expect { subject.add_site!(site: new_site) }.to change { subject.reload.site_statuses.size }.
          from(0).to(1)
        expect(new_site_status.status).to eq("new_status")
      end
    end

    context "for mixed course with new and running locations" do
      let(:existing_site_status) { create(:site_status, :running, :published, site: existing_site) }
      let(:another_existing_site) { create(:site, provider: provider) }
      let(:existing_new_site_status) { create(:site_status, :new, site: another_existing_site) }
      subject { create(:course, site_statuses: [existing_site_status, existing_new_site_status]) }

      it "adds a new site status and sets it to running when a new site is added" do
        expect { subject.add_site!(site: new_site) }.to change { subject.reload.site_statuses.size }.
          from(2).to(3)
        expect(new_site_status.status).to eq("running")
      end

      it "suspends the site when an existing site is removed" do
        expect { subject.remove_site!(site: existing_site) }.
          to change { existing_site_status.reload.status }.from("running").to("suspended")
      end
    end
  end
end
