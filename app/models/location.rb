class Location < ActiveRecord::Base
  belongs_to :loc_group

  has_many :time_slots
  has_many :shifts
  has_and_belongs_to_many :data_objects

  validates_presence_of :loc_group
  validates_presence_of :name
  validates_presence_of :short_name
  validates_presence_of :min_staff
  validates_numericality_of :max_staff
  validates_numericality_of :min_staff
  validates_numericality_of :priority

  validates_uniqueness_of :name, :scope => :loc_group_id
  validates_uniqueness_of :short_name, :scope => :loc_group_id
  validate :max_staff_greater_than_min_staff

  delegate :department, :to => :loc_group

  def admin_permission
    self.loc_group.admin_permission
  end

  def locations
    [self]
  end

  def find_notices
    Notice.active.select {|n| n.display_locations.include?(self)}
  end

  def stickys
    self.find_notices.select {|n| n.is_sticky}
  end

  def announcements
    self.find_notices.select {|n| !(n.is_sticky)}
  end
  
  def restrictions #TODO: this could probalby be optimized
    Restriction.all.select{|r| r.locations.include?(self)}
  end
  

  def count_people_for(shift_list, min_block)
    people_count = {}
    people_count.default = 0
    unless shift_list.nil?
      shift_list.each do |shift|
        t = shift.start
        while (t<shift.end)
          people_count[t.to_s(:am_pm)] += 1
          t += min_block
        end
      end
    end
    people_count
  end
  
  
  protected
  
  def max_staff_greater_than_min_staff
    errors.add("The minimum number of staff cannot be larger than the maximum.", "") if (self.min_staff and self.max_staff and self.min_staff > self.max_staff)
  end
  
end

