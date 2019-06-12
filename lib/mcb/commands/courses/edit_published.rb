name 'edit_published'
summary 'Edit published course directly in the DB'

def add_or_remove_sites_from(course, provider, cli)
  toggling_finished = false
  until toggling_finished do
    cli.choose do |menu|
      menu.prompt = "Toggling course sites for #{course.course_code}"
      menu.choice(:done) { toggling_finished = true }
      provider.sites.order(:location_name).each do |site|
        if site.in?(course.sites)
          menu.choice("[x] #{site.description}") { course.remove_site!(site: site) }
        else
          menu.choice("[ ] #{site.description}") { course.add_site!(site: site) }
        end
      end
    end
    course.sites.reload
  end
end

run do |opts, args, _cmd|
  MCB.init_rails(opts)

  cli = HighLine.new
  provider = Provider.find_by!(provider_code: args[0].upcase)

  all_courses_mode = args.size == 1
  courses = if all_courses_mode
              provider.courses
            else
              provider.courses.where(course_code: args.to_a.map(&:upcase))
            end

  multi_course_mode = courses.size > 1

  finished = false
  until finished do
    choice = cli.choose do |menu|
      courses[0..1].each { |c| puts Terminal::Table.new rows: MCB::CourseShow.new(c).to_h }
      puts "Only showing first 2 courses of #{courses.size}." if courses.size > 2

      menu.prompt = "Editing " + (multi_course_mode ? "multiple courses" : "course #{courses.first.course_code}")
      menu.choice(:exit) { finished = true }
      menu.choice(:toggle_sites) unless multi_course_mode
      menu.choice('Publish training locations (not enrichment)')
    end

    case choice
    when :toggle_sites
      add_or_remove_sites_from(courses.first, provider, cli)
    when 'Publish training locations (not enrichment)'
      courses.each do |course|
        puts "Setting the training locations to running on #{course.provider.provider_code}/#{course.course_code}"
        course.publish_sites
        course.reload
      end
    end
  end
end
