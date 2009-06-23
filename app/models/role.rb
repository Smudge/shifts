class Role < ActiveRecord::Base
  has_and_belongs_to_many :departments
  has_and_belongs_to_many :permissions
  has_and_belongs_to_many :users

  has_many :user_source_links, :as => :user_source

  validates_presence_of :name
  validate :must_belong_to_department
  validate :must_have_unique_name_in_dept #can't use scope because of habtm relationship :(

  # FIXME: only role of user admin permission can belong to more than one department.
  # should user_admin role and loc_group roles be separated?
  def must_belong_to_department
    errors.add("Role must belong to a department.", "") if self.departments.empty?
  end

  def must_have_unique_name_in_dept
    #get a list of roles in the same department as this role, excluding this role
    associated_roles = self.departments.collect{|dept| dept.roles}.flatten - [self]

    errors.add("Name must be unique in a department.", "") unless associated_roles.select{ |role| role.name == self.name }.empty?
  end
end

