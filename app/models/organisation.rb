# == Schema Information
#
# Table name: organisation
#
#  id     :integer          not null, primary key
#  name   :text
#  org_id :text
#

class Organisation < ApplicationRecord
  has_many :organisation_users

  # dependent destroy because https://stackoverflow.com/questions/34073757/removing-relations-is-not-being-audited-by-audited-gem/34078860#34078860
  has_many :users, through: :organisation_users, dependent: :destroy

  has_and_belongs_to_many :providers
  has_many :nctl_organisations

  validates :name, presence: true

  has_associated_audits
  audited

  def accredited_nctl_organisation
    nctl_organisations.accredited_body.first
  end

  def school_nctl_organisation
    if nctl_organisations.school.count > 1
      raise "more than one school nctl organisation found"
    end

    nctl_organisations.school.first
  end
end
