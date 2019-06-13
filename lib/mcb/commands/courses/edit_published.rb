name 'edit_published'
summary 'Edit published course directly in the DB'

def publish_sites_for(courses)
  courses.each do |course|
    puts "Setting the training locations to running on #{course.provider.provider_code}/#{course.course_code}"
    course.publish_sites
    course.reload
  end
end

run do |opts, args, _cmd|
  MCB.init_rails(opts)

  cli = HighLine.new
  provider = Provider.find_by!(provider_code: args[0].upcase)
  course_codes = args.to_a[1..-1].map(&:upcase)
  courses = provider.courses
  courses = courses.where(course_code: course_codes) unless course_codes.empty?

  finished = false
  until finished do
    choice = cli.choose do |menu|
      courses[0..1].each { |c| puts Terminal::Table.new rows: MCB::CourseShow.new(c).to_h }
      puts "Only showing first 2 courses of #{courses.size}." if courses.size > 2

      menu.prompt = "Editing #{'course'.pluralize(courses.size)}: #{courses.pluck(:course_code).sort.join(', ')}"
      menu.choice(:exit) { finished = true }
      menu.choice('Publish training locations (not enrichment)')
    end

    case choice
    when 'Publish training locations (not enrichment)'
      publish_sites_for(courses)
    end
  end
end
