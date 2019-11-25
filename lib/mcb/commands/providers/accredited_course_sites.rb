name "accredited_courses"
summary "Show courses this provider is the accredited body for"
param :code, transform: ->(code) { code.upcase }
option :f, "csv-file", "output to a file in csv format", argument: :required

run do |opts, args, _cmd|
  MCB.init_rails(opts)
  code = args[:code]
  provider = MCB.get_recruitment_cycle(opts).providers.find_by!(provider_code: code)
  if provider.nil?
    error "Provider with code '#{code}' not found"
  else
    services = ServiceContainer.new
    report_service = services.get(:providers, :reports)
    course_data = report_service.get_accredited_courses(provider)
    write_course_data(course_data, opts[:"csv-file"])
  end
end

def write_course_data(course_data, output_filename = nil)
  if output_filename
    write_to_csv_file(output_filename, course_data)
  else
    tp course_data
  end
end

def write_to_csv_file(file, data)
  # https://stackoverflow.com/questions/8183706/how-to-save-a-hash-into-a-csv/31613233#31613233
  CSV.open(file, "w", write_headers: true, headers: data.first.keys) do |csv|
    data.each do |row|
      csv << row.values
    end
    puts "#{data.length} rows written to #{file}"
  end
end
