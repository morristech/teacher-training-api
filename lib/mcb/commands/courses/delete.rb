summary "Delete one or more courses directly from the DB"
usage "delete <provider_code> <course code 1> [<course code 2> ...]"
param :provider_code, transform: ->(code) { code.upcase }

run do |opts, args, _cmd|
  MCB.init_rails(opts)

  Course.connection.transaction do
    provider = MCB.get_recruitment_cycle(opts).providers.find_by!(provider_code: args[:provider_code])
    requester = User.find_by!(email: MCB.config[:email])

    MCB::Editor::CoursesEditor.new(
      provider: provider,
      requester: requester,
      courses: [provider.courses.build],
      )
  end
end
