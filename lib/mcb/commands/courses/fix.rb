# rubocop:disable Metrics/BlockLength
name "fix incorrect courses"
summary "Fix courses with incorrect levels and subjects"

run do |opts, _args, _cmd|
  MCB.init_rails(opts)

  courses = [
    { provider_code: "2C7", course_code: "E723" },
    { provider_code: "1E5", course_code: "E256" },
    { provider_code: "1E5", course_code: "E234" },
    { provider_code: "1E5", course_code: "E356" },
    { provider_code: "1E5", course_code: "E589" },
    { provider_code: "1E5", course_code: "E691" },
    { provider_code: "1E5", course_code: "E712" },
    { provider_code: "2BU", course_code: "E834" },
    { provider_code: "1E5", course_code: "E367" },
    { provider_code: "1E5", course_code: "E478" },
    { provider_code: "1E5", course_code: "E591" },
    { provider_code: "1E5", course_code: "E612" },
    { provider_code: "1E5", course_code: "E945" },
    { provider_code: "1E5", course_code: "E267" },
    { provider_code: "1E5", course_code: "E378" },
    { provider_code: "1E5", course_code: "E489" },
    { provider_code: "1E5", course_code: "E512" },
    { provider_code: "1E5", course_code: "E823" },
    { provider_code: "1E5", course_code: "E934" },
    { provider_code: "1E5", course_code: "E145" },
    { provider_code: "1E5", course_code: "E634" },
    { provider_code: "1E5", course_code: "E756" },
    { provider_code: "1E5", course_code: "E878" },
    { provider_code: "1K2", course_code: "E989" },
    { provider_code: "1K2", course_code: "E191" },
    { provider_code: "1K2", course_code: "E212" },
    { provider_code: "1K2", course_code: "E313" },
    { provider_code: "1K2", course_code: "E414" },
    { provider_code: "1K2", course_code: "E515" },
    { provider_code: "1K2", course_code: "E616" },
    { provider_code: "1K2", course_code: "E717" },
    { provider_code: "1K2", course_code: "E818" },
    { provider_code: "1K2", course_code: "E919" },
    { provider_code: "1K2", course_code: "E111" },
    { provider_code: "1K2", course_code: "E121" },
    { provider_code: "1K2", course_code: "E222" },
    { provider_code: "1K2", course_code: "E323" },
    { provider_code: "1K2", course_code: "E424" },
    { provider_code: "1K2", course_code: "E525" },
    { provider_code: "1K2", course_code: "E626" },
    { provider_code: "1K2", course_code: "E727" },
    { provider_code: "1K2", course_code: "E828" },
    { provider_code: "1K2", course_code: "E929" },
    { provider_code: "1K2", course_code: "E131" },
    { provider_code: "1K2", course_code: "E232" },
    { provider_code: "18Z", course_code: "E151" },
    { provider_code: "18Z", course_code: "E949" },
    { provider_code: "18Z", course_code: "E848" },
    { provider_code: "18Z", course_code: "E747" },
    { provider_code: "18Z", course_code: "E646" },
    { provider_code: "18Z", course_code: "E545" },
    { provider_code: "16F", course_code: "E242" },
    { provider_code: "18Z", course_code: "E444" },
    { provider_code: "16F", course_code: "E141" },
    { provider_code: "18Z", course_code: "E343" },
    { provider_code: "16F", course_code: "E939" },
    { provider_code: "16F", course_code: "E838" },
    { provider_code: "1JA", course_code: "E737" },
    { provider_code: "1GP", course_code: "E636" },
    { provider_code: "1JA", course_code: "E535" },
    { provider_code: "1GT", course_code: "E434" },
    { provider_code: "1V9", course_code: "E333" },
  ]

  time = Benchmark.measure do
    recruitment_cycle = RecruitmentCycle.current

    all_subjects = Subject.all

    courses.each do |broken_course|
      puts "Fixing: #{broken_course[:provider_code]}, #{broken_course[:course_code]}"
      provider = recruitment_cycle.providers.find_by(provider_code: broken_course[:provider_code])
      course = provider.courses.find_by(course_code: broken_course[:course_code])

      course.update_column(:level, course.ucas_level)

      dfe_subjects = course.dfe_subjects.map{|dfe_subject| dfe_subject.to_s.downcase}
      course.subjects = all_subjects.select{|subject| subject.subject_name.downcase.in? dfe_subjects}
      course.save!
    end
  end

  puts "Time taken: %0.3f seconds" % time.real
end
# rubocop:enable Metrics/BlockLength
