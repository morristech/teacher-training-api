require "rails_helper"

describe User, type: :model do
  subject { create(:user, first_name: "Jane", last_name: "Smith", email: "jsmith@scitt.org") }

  describe "associations" do
    it { should have_many(:organisation_users) }
    it { should have_many(:organisations).through(:organisation_users) }
    it { should have_many(:providers).through(:organisations) }
    it { should have_many(:user_notifications) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:email).with_message("must contain @") }
    it { should_not allow_value("CAPS_IN_EMAIL@ACME.ORG").for(:email) }
    it { should_not allow_value("email_without_at").for(:email) }
    it { should_not allow_value(nil).for(:first_name) }
    it { should_not allow_value(nil).for(:last_name) }
    it { should_not allow_value("").for(:first_name) }
    it { should_not allow_value("").for(:last_name) }
    it { should_not allow_value("  ").for(:first_name) }
    it { should_not allow_value("  ").for(:last_name) }

    context "for an admin-user" do
      subject { create(:user, :admin) }
      it { should_not allow_value("general.public@example.org").for(:email) }
      it { should_not allow_value("some.provider@devon.gov.uk").for(:email) }
      it { should allow_value("bobs.your.uncle@digital.education.gov.uk").for(:email) }
      it { should allow_value("right.malarky@education.gov.uk").for(:email) }
    end
  end

  describe "auditing" do
    it { should be_audited }
  end

  describe "states" do
    context "new user" do
      it { should be_new }
    end
  end

  describe "transition state event" do
    before do
      subject.accept_transition_screen!
    end

    it { should be_transitioned }
  end

  describe "rollover state event" do
    before do
      subject.accept_transition_screen!
      subject.accept_rollover_screen!
    end

    it { should be_rolled_over }
  end

  describe "#to_s" do
    its(:to_s) { should eq("Jane Smith <jsmith@scitt.org>") }
  end

  describe "#admin?" do
    context "user is an admin" do
      subject! { create(:user, :admin) }

      its(:admin?) { should be_truthy }

      it "shows up in User.admins" do
        expect(User.admins).to eq([subject])
      end

      it "doesn't show up in User.non_admins" do
        expect(User.non_admins).to be_empty
      end
    end

    context "user is not an admin" do
      subject { create(:user) }

      context "when other domain" do
        its(:admin?) { should be_falsey }

        it "is a non-admin user" do
          expect(User.non_admins).to eq([subject])
        end

        it "is not an admin" do
          expect(User.admins).to be_empty
        end
      end
    end
  end

  describe ".active" do
    let!(:inactive_user) { create(:user, :inactive) }
    let!(:active_user) { create(:user, accept_terms_date_utc: Date.yesterday) }

    it "includes active users and excludes inactive users" do
      expect(User.active).to eq([active_user])
    end
  end

  describe "#remove_access_to" do
    let(:organisation) { create(:organisation) }
    let(:other_organisation) { create(:organisation) }
    let(:yet_other_organisation) { create(:organisation) }

    describe "one organisation" do
      before do
        subject.organisations = [organisation, other_organisation]
        subject.remove_access_to(organisation)
      end

      it "removes the right organisation"do
        expect(subject.reload.organisations).to eq([other_organisation])
      end
    end

    describe "multiple organisations" do
      before do
        subject.organisations = [organisation, other_organisation, yet_other_organisation]
        subject.remove_access_to [organisation, yet_other_organisation]
      end

      it "removes the right organisation"do
        expect(subject.reload.organisations).to eq([other_organisation])
      end
    end
  end

  describe "#discard" do
    subject { create(:user) }

    context "before discarding" do
      its(:discarded?) { should be false }

      it "is in kept" do
        expect(User.kept).to eq([subject])
      end

      it "is not in discarded" do
        expect(User.discarded).to be_empty
      end
    end

    context "after discarding" do
      before do
        subject.discard
      end

      its(:discarded?) { should be true }

      it "is not in kept" do
        expect(User.kept).to be_empty
      end

      it "is in discarded" do
        expect(User.discarded).to eq([subject])
      end
    end
  end

  describe ".last_login_since" do
    context "30 days ago" do
      let!(:over_30_user) { create(:user, last_login_date_utc: 30.days.ago) }
      let!(:under_30_user) { create(:user, last_login_date_utc: 29.days.ago) }

      it "includes users logged in less than 30 days ago" do
        expect(described_class.last_login_since(30.days.ago)).to eq([under_30_user])
      end
    end
  end
end
