class AddMainAndOtherToCourseSubject < ActiveRecord::Migration[6.0]
  def change
    add_column :course_subject, :main, :boolean, default: false
  end
end
