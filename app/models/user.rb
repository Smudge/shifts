require 'net/ldap'
class User < ActiveRecord::Base
  acts_as_authentic do |options|
    options.maintain_sessions false
  end
  has_and_belongs_to_many :roles
  has_many :departments_users
  has_many :departments, :through => :departments_users
  has_many :payforms
  has_many :payform_items, :through => :payforms
  has_many :shifts
  has_many :notices, :as => :author
  has_many :notices, :as => :remover
  has_one  :punch_clock

  # New user configs are created by a user observer, after create
  has_one :user_config, :dependent => :destroy

  attr_protected :superuser
  named_scope :superusers, :conditions => { :superuser => true }, :order => "last_name"
  delegate :default_department, :to => 'user_config'

  validates_presence_of :first_name
  validates_presence_of :last_name
  validates_presence_of :login
  validates_presence_of :auth_type
  validates_uniqueness_of :login
  validate :departments_not_empty

  # memoize allows more powerful caching of instance variable in methods
  # memoize line must be added after the method definitions (see below)
  extend ActiveSupport::Memoizable


  def self.import_from_ldap(login, department = nil, should_save = false)
    # Setup our LDAP connection
    ldap = Net::LDAP.new( :host => $appconfig.ldap_host_address, :port => $appconfig.ldap_port )
#    begin
      # We filter results based on login
      filter = Net::LDAP::Filter.eq($appconfig.ldap_login, login)
      new_user = User.new(:login => login)
      ldap.open do |ldap|
        # Search, limiting results to yale domain and people
        ldap.search(:base => $appconfig.ldap_base, :filter => filter, :return_result => false ) do |entry|
          # Make sure only 1 record is found
          Rails.logger.info(entry)
          raise "LDAP: more than one result is found" if entry[$appconfig.ldap_first_name].size > 1

          new_user.first_name = entry[$appconfig.ldap_first_name].first
          new_user.last_name  = entry[$appconfig.ldap_last_name].first
          new_user.email = entry[$appconfig.ldap_email].first

        end
        #add the user to the currently selected department
        new_user.departments << department if department
      end
      new_user.save if should_save
#    rescue Exception => e
#    raise e.message # Will trigger an error, LDAP is probably down
#    end
    new_user
  end

  def self.search_ldap(first_name, last_name, email, login, limit)
    first_name+='*'
    last_name+='*'
    email+='*'
    login+='*'
    # Setup our LDAP connection
    ldap = Net::LDAP.new( :host => $appconfig.ldap_host_address, :port => $appconfig.ldap_port )
    filter = Net::LDAP::Filter.eq($appconfig.ldap_first_name, first_name) & Net::LDAP::Filter.eq($appconfig.ldap_last_name, last_name) & Net::LDAP::Filter.eq($appconfig.ldap_email, email) & Net::LDAP::Filter.eq($appconfig.ldap_login, login)
    out=[]
    ldap.open do |ldap|
      ldap.search(:base => $appconfig.ldap_base, :filter => filter, :return_result => false) do |entry|
      out << {:login => entry[$appconfig.ldap_login][0],
              :email => entry[$appconfig.ldap_email][0],
              :first_name => entry[$appconfig.ldap_first_name][0],
              :last_name => entry[$appconfig.ldap_last_name][0]}
       break if out.length>=limit
      end
    end
    out
  end

  def self.mass_add(logins, department)
    failed = []

    logins.split(/\W+/).map do |n|
      if user = self.find_by_login(n)
        user.departments << department
      else
        user = import_from_ldap(n, department, true)
      end
      failed << "From login #{user.login}: #{user.errors.full_messages.to_sentence} (LDAP import may have failed)" if user.new_record?
    end

    failed
  end

  def self.search(search_string)
    self.all.each do |u|
      if u.name == search_string || u.proper_name == search_string || u.awesome_name == search_string || u.login == search_string
        @found_user =  u
      end
    end
    @found_user
  end

  def permission_list
    roles.collect { |r| r.permissions }.flatten
  end

  def current_shift
    self.shifts.select{|shift| shift.signed_in? and !shift.submitted?}[0]
  end

  # Returns all the loc groups a user can view within a given department
  def loc_groups(dept)
    dept.loc_groups.delete_if{|lg| !self.can_view?(lg)}
  end

  # check if a user can see locations and shifts under this loc group
  def can_view?(loc_group)
    return false unless loc_group
    self.is_superuser? || permission_list.include?(loc_group.view_permission) && self.is_active?(loc_group.department)
  end

  # check if a user can sign up for a shift in this loc group
  def can_signup?(loc_group)
    return false unless loc_group
    self.is_superuser? || permission_list.include?(loc_group.signup_permission) && self.is_active?(loc_group.department)
  end

  # check for admin permission given a dept, location group, or location
  def is_admin_of?(dept)
    return false unless dept
    self.is_superuser? || (permission_list.include?(dept.admin_permission) && self.is_active?(dept))
  end

  # now superuser is an attribute of User model, we use this instead
  # supermode lets an user turn on or off his superuser privilege
  # user .superuser? is you wanna test superuser no matter if  supermode is on or not
  def is_superuser?
    superuser? && supermode?
  end

  # check to make sure the user is "active" in the given dept
  def is_active?(dept)
    self.departments_users[0].active
  end

  # Given a department, check to see if the user can admin any loc groups in it
  def is_loc_group_admin?(dept)
    dept.loc_groups.any?{|lg| self.is_admin_of?(lg)}
  end

  # Given a department, return any location groups within that department that the user can admin
  def loc_groups_to_admin(dept)
    return dept.loc_groups if self.is_admin_of?(dept)
    dept.loc_groups.delete_if{|lg| !self.is_admin_of?(lg)}
  end

  def name
    [((nick_name.nil? or nick_name.length == 0) ? first_name : nick_name), last_name].join(" ")
  end

  def proper_name
    [first_name, last_name].join(" ")
  end

  def awesome_name
    [nick_name ? [first_name, "\"#{nick_name}\"", last_name] : self.name].join(" ")
  end

  def users
    [self]
  end

  def available_sub_requests #TODO: this could probalby be optimized
    SubRequest.all.select{|sr| sr.substitutes.include?(self)}
  end

  def notices #TODO: this could probalby be optimized
    Notice.active.select{|n| n.viewers.include?(self)}
  end

  def restrictions #TODO: this could probalby be optimized
    Restriction.all.select{|r| r.users.include?(self)}
  end

#TODO: A method like this might be helpful
#  def switch_auth_type
#    if self.auth_type=='CAS'
#      self.auth_type='authlogic'
#      self.deliver_password_reset_instructions!(Proc.new {|n| AppMailer.deliver_change_auth_type_password_reset_instructions (n)})
#      self.save!
#    else
#      self.auth_type='CAS'
#      self.save!
#    end
#  end

  def deliver_password_reset_instructions!(mailer)
    self.reset_perishable_token!
    mailer.call(self)
  end

  memoize :name, :permission_list

  def accessible_departments
    (superuser? && supermode?) ? Department.all : departments
  end

  def current_notices
    Notice.active.select {|n| n.users.include?(self)}
  end
  
  private

  def departments_not_empty
    errors.add("User must have at least one department.", "") if departments.empty?
  end

  def create_user_config
    UserConfig.new({:user_id => self.id}).save
  end
end
