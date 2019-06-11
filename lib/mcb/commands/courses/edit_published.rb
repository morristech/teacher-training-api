name 'edit_published'
summary 'Edit published course directly in the DB'

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

  flow = :root
  finished = false
  until finished do
    case flow
    when :root
      cli.choose do |menu|
        courses[0..1].each { |c| puts Terminal::Table.new rows: MCB::CourseShow.new(c).to_h }
        puts "Only showing first 2 courses of #{courses.size}." if courses.size > 2

        if multi_course_mode
          menu.prompt = "Editing multiple courses"
        else
          menu.prompt = "Editing course #{courses.first.course_code}"
        end
        menu.choice(:exit) { finished = true }
        menu.choice(:toggle_sites) { flow = :toggle_sites } unless multi_course_mode
        menu.choice('Publish training locations (not enrichment)') { flow = :publish_sites }
        menu.choice('Sync courses to Find') { flow = :sync_to_find }
      end
    when :toggle_sites
      course = courses.first
      cli.choose do |menu|
        menu.prompt = "Toggling course sites for #{course.course_code}"
        menu.choice(:done) { flow = :root }
        provider.sites.order(:location_name).each do |site|
          if !site.in?(course.site_statuses.map(&:site))
            menu.choice(site.description) {
              course.add_site!(site: site)
            }
          else
            site_status = course.site_statuses.detect { |ss| ss.site == site }
            menu.choice(site_status.description) do
              if site_status.status_running? || site_status.status_new_status?
                course.remove_site!(site: site)
              else
                course.add_site!(site: site)
              end
            end
          end
        end
      end
    when :publish_sites
      courses.each do |course|
        puts "Setting the training locations to running on #{course.provider.provider_code}/#{course.course_code}"
        course.publish_sites
      end
      flow = :root
    else
      puts "Unexpected option: #{flow}"
      flow = :root
    end
    unless finished
      courses.each(&:save!)
      provider.reload
      courses.reload
      courses.first.site_statuses.reload unless multi_course_mode
    end
  end
end
