class UniqueSiteStatus < ActiveRecord::Migration[6.0]
  def up
    puts "De-duping course_site. Count before: #{SiteStatus.count}"
    # https://stackoverflow.com/questions/14124212/remove-duplicate-records-based-on-multiple-columns/14124391#14124391
    grouped = SiteStatus.all.group_by { |cs| [cs.course_id, cs.site_id] }
    grouped.values.each do |dupes|
      dupes.shift
      dupes.each(&:destroy)
    end
    puts "De-duping course_site. Count after: #{SiteStatus.count}"
    remove_index :course_site, %i[course_id site_id]
  end

  def down
    remove_index :course_site, %i[course_id site_id]
  end
end
