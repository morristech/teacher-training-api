name 'create'
summary 'Create a new course in db'
usage 'create <provider_code>'
param :provider_code, transform: ->(code) { code.upcase }

class CourseEditor
  def initialize(provider:, requester:)
    @cli = HighLine.new
    @course = provider.courses.build

    @courses_editor = MCB::CoursesEditor.new(
      provider: provider,
      courses: [@course],
      requester: requester,
    )
  end

  def new_course_wizard
    @courses_editor.edit(:title)
    @courses_editor.edit(:qualifications)
    @courses_editor.edit(:study_mode)
    @courses_editor.edit(:accredited_body)
    @courses_editor.edit(:start_date)
    @courses_editor.edit(:route)
    @courses_editor.edit(:maths)
    @courses_editor.edit(:english)
    @courses_editor.edit(:science)
    ask_age_range
    ask_course_code

    if confirm_creation?
      try_saving_course
      ask_ucas_subjects
      ask_sites
      @courses_editor.edit(:application_opening_date)
      print_summary
    else
      puts "Aborting"
    end
  end

  def ask_age_range
    @course.age_range = @cli.choose do |menu|
      menu.prompt = "What's the level of the course?  "
      menu.choices(*Course.age_ranges.keys)
    end
  end

  def ask_course_code
    @course.course_code = @cli.ask("Course code?  ")
  end

  def ask_ucas_subjects
    toggling_finished = false
    until toggling_finished do
      @cli.choose do |menu|
        menu.choice(:exit) { toggling_finished = true }
        ::Subject.all.order(:subject_name).each do |subject|
          if subject.in?(@course.subjects)
            menu.choice("[x] #{subject.subject_name}") { @course.subjects.delete(subject) }
          else
            menu.choice("[ ] #{subject.subject_name}") { @course.subjects << subject }
          end
        end
      end
      @course.subjects.reload
    end
  end

  def ask_sites
    finished = false
    until finished
      @cli.choose do |menu|
        sites_list = !@course.sites.empty? ? "(#{@course.sites.map(&:location_name).join(', ')} so far)" : ""
        menu.prompt = "Which training locations to assign? #{sites_list}  "

        menu.choice("No more training locations") { finished = true }
        @course.provider.sites.each do |site|
          menu.choice(site.location_name) { @course.add_site!(site: site) }
        end
      end
    end
  end

  def confirm_creation?
    puts "\nAbout to create the following course:"
    print_course
    @cli.agree("Continue? ")
  end

  def print_summary
    puts "\nHere's the final course that's been created:"
    print_course
    @cli.ask("Press Enter to continue")
  end

  def print_course
    puts MCB::Render::ActiveRecord.course(@course)
  end

  def try_saving_course
    if @course.valid?
      puts "Saving the course"
      @course.save!
    else
      puts "Course isn't valid:"
      @course.errors.full_messages.each { |error| puts " - #{error}" }
    end
  end
end

run do |opts, args, _cmd|
  MCB.init_rails(opts)

  Course.connection.transaction do
    provider = Provider.find_by!(provider_code: args[:provider_code])
    requester = User.find_by!(email: MCB.config[:email])
    CourseEditor.new(provider: provider, requester: requester).new_course_wizard
  end
end
