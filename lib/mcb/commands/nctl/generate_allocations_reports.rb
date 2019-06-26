# coding: utf-8
summary 'Generate allocation reports for a given NCTL ID'
usage 'generate_allocations_report <template path> <nctl ID>'

option :C, :contacts, 'contacts file',
       argument: :required,
       default: '2020-21 ITT Allocations Officer.csv'

run do |opts, args, _cmd|
  MCB.init_rails(opts)

  template_path = File.expand_path(args[0])
  verbose "template: #{template_path}"

  nctl_organisations = if args[1].present?
                         nctl_contacts(opts).slice(args[1])
                       else
                         nctl_contacts(opts)
                       end

  require 'csv'
  CSV do |csv_out|
    csv_out << ['nctl_id', 'email address', 'provider_name', 'template_url']

    nctl_organisations.each do |nctl_id, nctl_infos|
      # This turns out not to work as well as we hoped (see 10655 -> 10796,
      # both exist in their data)
      #
      # nctl_id = nctl_mappings[nctl_id] if nctl_mappings.key?(nctl_id)

      # Because of group_by the nctl_infos is an array of arrays:
      #   [
      #    [nctl_id1, name, email1]
      #    [nctl_id2, name, email1]
      #   ]
      emails = nctl_infos.map(&:last)
      org_name = nctl_infos.first.second
      nctl_organisation = NCTLOrganisation.find_by nctl_id: nctl_id
      output_filename = if nctl_organisation
                          nctl_organisation.save_allocations_report(template_path)
                        else
                          'Allocations_requests_template_ITT2020.xlsx'
                        end
      emails.map do |email|
        csv_out << [
          nctl_id,
          email,
          org_name,
          "https://sadfebatallocations.blob.core.windows.net/find-allocations/#{output_filename}"
        ]
      end
    end

    # nctl_organisations.each do |nctl_organisation|
    #   verbose "Generating allocations report for #{nctl_organisation}"
    #   output_filename = nctl_organisation.save_allocations_report(template_path)
    #   # email address,provider_name,template_url
    #   csv_out << [nctl_organisation.nctl_id, nctl_organisation.name, output_filename]
    # end
  end
end

def nctl_contacts(**opts)
  @nctl_contacts ||=
    CSV.read(opts[:contacts], headers: true)
      .map do |row|
    row.to_h.slice('Provider ID (Organisation Name) (Organisation)',
                   'Organisation Name (Allocation Officer)',
                   'Email').values
  end .group_by(&:first)

  # email,nctl_id
  @nctl_contacts ||= CSV.parse(<<~EOCSV).map(&:reverse).group_by(&:first)
    head@thorndown.cambs.sch.uk,Thorndown Primary School,16328
  EOCSV
end
