class UserObserver < ActiveRecord::Observer

  # Automatically create user config for a user
  def after_create(user)
    UserConfig.create!({:user_id => user.id,
                        :view_loc_groups => "",
                        :view_week => "",
                        :default_dept => user.departments.first.id
                        })
  end

end

