class Shift < ActiveRecord::Base

  delegate :loc_group, :to => 'location'
  belongs_to :calendar
  belongs_to :repeating_event
  belongs_to :department
  belongs_to :user
  belongs_to :location
  has_one :report, :dependent => :destroy
  has_many :sub_requests, :dependent => :destroy

  validates_presence_of :user
  validates_presence_of :location
  validates_presence_of :start

  named_scope :on_day, lambda {|day| { :conditions => ['"start" >= ? and "start" < ?', day.beginning_of_day.utc, day.end_of_day.utc]}}
  named_scope :on_days, lambda {|start_day, end_day| { :conditions => ['"start" >= ? and "start" < ?', start_day.beginning_of_day.utc, end_day.end_of_day.utc]}}
  named_scope :in_location, lambda {|loc| {:conditions => {:location_id => loc.id}}}
  named_scope :in_locations, lambda {|loc_array| {:conditions => { :location_id => loc_array }}}
  named_scope :scheduled, lambda {{ :conditions => {:scheduled => true}}}
  named_scope :super_search, lambda {|start,stop, incr,locs| {:conditions => ['(("start" >= ? and "start" < ?) or ("end" > ? and "end" <= ?)) and "scheduled" = ? and "location_id" IN (?)', start.utc, stop.utc - incr, start.utc + incr, stop.utc, true, locs], :order => '"location_id", "start"' }}
  named_scope :hidden_search, lambda {|start,stop,day_start,day_end,locs| {:conditions => ['(("start" >= ? and "end" < ?) or ("start" >= ? and "start" < ?)) and "scheduled" = ? and "location_id" IN (?)', day_start.utc, start.utc, stop.utc, day_end.utc, true, locs], :order => '"location_id", "start"' }}

  #TODO: clean this code up -- maybe just one call to shift.scheduled?
  validates_presence_of :end, :if => Proc.new{|shift| shift.scheduled?}
  validates_presence_of :user
  validate :start_less_than_end, :if => Proc.new{|shift| shift.scheduled?}
  validate :shift_is_within_time_slot, :if => Proc.new{|shift| shift.scheduled?}
  validate :user_does_not_have_concurrent_shift, :if => Proc.new{|shift| shift.scheduled?}
  validate_on_create :not_in_the_past, :if => Proc.new{|shift| shift.scheduled?}
  validate :restrictions
  before_save :adjust_sub_requests
  before_save :combine_with_surrounding_shifts

  #
  # Class methods
  #

  def self.delete_part_of_shift(shift, start_of_delete, end_of_delete)
    #Used for taking sub requests
    if !(start_of_delete.between?(shift.start, shift.end) && end_of_delete.between?(shift.start, shift.end))
      raise "You can\'t delete more than the entire shift"
  elsif start_of_delete >= end_of_delete
      raise "Start of the deletion should be before end of deletion"
    elsif start_of_delete == shift.start && end_of_delete == shift.end
      shift.destroy
    elsif start_of_delete == shift.start
      shift.start=end_of_delete
      shift.save!
    elsif end_of_delete == shift.end
      shift.end=start_of_delete
      shift.save!
    else
      later_shift = shift.clone
      later_shift.user = shift.user
      later_shift.location = shift.location
      shift.end = start_of_delete
      later_shift.start = end_of_delete
      shift.save!
      later_shift.save!
      shift.sub_requests.each do |s|
        if s.start >= later_shift.start
          s.shift = later_shift
          s.save!
        end
      end
    end
  end

  #This method creates the multitude of shifts required for repeating_events to work
  #in order to work efficiently, it makes a few GIANT sql insert calls
  def self.make_future(end_date, cal_id, r_e_id, days, loc_id, start_time, end_time, user_id, department_id)
    #We need several inner arrays with one big outer one, b/c sqlite freaks out if the sql insert call is too big
    outer = []
    inner = []
    #Take each day and build an array containing the pieces of the sql query
    days.each do |day|
      seed_start_time = start_time
      seed_end_time = end_time
      while seed_end_time <= end_date
        seed_start_time = seed_start_time.next(day)
        seed_end_time = seed_end_time.next(day)
        inner.push "\"#{loc_id}\", \"#{cal_id}\", \"#{r_e_id}\", \"#{seed_start_time.to_s(:sql)}\", \"#{seed_end_time.to_s(:sql)}\", \"#{Time.now.to_s(:sql)}\", \"#{Time.now.to_s(:sql)}\", \"#{user_id}\", \"#{department_id}\""
        #Once the array becomes big enough that the sql call will insert 450 rows, start over w/ a new array
        #without this bit, sqlite freaks out if you are inserting a larger number of rows. Might need to be changed
        #for other databases (it can probably be higher for other ones I think, which would result in faster execution)
        if inner.length > 450
          outer.push inner
          inner = []
        end
      end
      #handle leftovers or the case where there are less than 450 rows to be inserted
      outer.push inner
    end
    #for each set of rows to be inserted, insert them, all within a transaction for speed's sake
    ActiveRecord::Base.transaction do
      outer.each do |s|
        sql = "INSERT INTO shifts ('location_id', 'calendar_id', 'repeating_event_id', 'start', 'end', 'created_at', 'updated_at', 'user_id', 'department_id') SELECT #{s.join(" UNION ALL SELECT ")};"
        ActiveRecord::Base.connection.execute sql
      end
    end
  end

  # ==================
  # = Object methods =
  # ==================

  def duration
    self.end - self.start
  end

  def css_class(current_user = nil)
    if current_user and user == current_user
      css_class = "user"
    else
      css_class = "shift"
    end
    if missed?
      css_class += "_missed"
    elsif (signed_in? ? report.arrived : Time.now) > start + department.department_config.grace_period*60 #seconds
      css_class += "_late"
    end
    css_class
  end

  def too_early?
    self.start > 30.minutes.from_now
  end

  def missed?
    self.has_passed? and !self.signed_in?
  end

  def late?
    self.signed_in? && (self.report.arrived - self.start > $department.department_config.grace_period*60)
    #seconds
  end

  #a shift has been signed in to if it has a report
  def signed_in?
    self.report
  end

  #a shift has been signed in to if its shift report has been submitted
  def submitted?
    self.signed_in? and self.report.departed
  end

  #TODO: subs!
  #check if a shift has a *pending* sub request and that sub is not taken yet
  def has_sub?
    #note: if the later part of a shift has been taken, self.sub still returns true so we also need to check self.sub.new_user.nil?
    !self.sub_requests.empty? #and sub.new_user.nil? #new_user in sub is only set after sub is taken.  shouldn't check new_shift bcoz a shift can be deleted from db. -H
  end

  def has_passed?
    self.end < Time.now
  end

  def has_started?
    self.start < Time.now
  end

  # If new shift runs up against another compatible shift, combine them and save,
  # preserving the earlier shift's information
  def combine_with_surrounding_shifts
    if (shift_later = Shift.find(:first, :conditions => {:start => self.end, :user_id => self.user_id, :location_id => self.location_id}))
      self.end = shift_later.end
      shift_later.sub_requests.each { |s| s.shift = self }
      shift_later.destroy
      self.save!
    end
    if (shift_earlier = Shift.find(:first, :conditions => {:end => self.start, :user_id => self.user_id, :location_id => self.location_id}))
      self.start = shift_earlier.start
      shift_earlier.sub_requests.each {|s| s.shift = self}
      shift_earlier.destroy
      self.save!
    end
  end

  def exceeds_max_staff?
    count = 0
    shifts_in_period = []
    Shift.find(:all, :conditions => {:location_id => self.location_id, :scheduled => true}).each do |shift|
      shifts_in_period << shift if (self.start..self.end).overlaps?(shift.start..shift.end) && self.end != shift.start && self.start != shift.end
    end
    increment = self.department.department_config.time_increment
    time = self.start + (increment / 2)
    while (self.start..self.end).include?(time)
      concurrent_shifts = 0
      shifts_in_period.each do |shift|
        concurrent_shifts += 1 if (shift.start..shift.end).include?(time)
      end
      count = concurrent_shifts if concurrent_shifts > count
      time += increment
    end
    count + 1 > self.location.max_staff
  end


  # ===================
  # = Display helpers =
  # ===================
  def short_display
     self.location.short_name + ', ' + self.start.to_s(:just_date) + ' ' + self.time_string
  end

  def short_name
    self.location.short_name + ', ' + self.user.name + ', ' + self.time_string + ", " + self.start.to_s(:just_date)
  end

  def time_string
    self.scheduled? ? self.start.to_s(:am_pm) + '-' + self.end.to_s(:am_pm) : "unscheduled"
  end


  private

  # ======================
  # = Validation helpers =
  # ======================
  def restrictions
    #location_restrictions = location.restrictions
    #user_restrictions = user.restrictions
    #TODO: RESTRICTIONS NEEDED TO BE FIXED - REMOVED CODE FOR NOW
  end

  def start_less_than_end
    errors.add(:start, "must be earlier than end time") if (self.end < start)
  end

  def shift_is_within_time_slot
    unless self.power_signed_up
      c = TimeSlot.count(:all, :conditions => ['location_id = ? AND start <= ? AND end >= ?', self.location_id, self.start, self.end])
      errors.add_to_base("You can only sign up for a shift during a time slot!") if c == 0
    end
  end

  def user_does_not_have_concurrent_shift

    c = Shift.count(:all, :conditions => ['user_id = ? AND start < ? AND end > ?', self.user_id, self.end, self.start])
    unless c.zero?
      errors.add_to_base("#{self.user.name} has an overlapping shift in that period") unless (self.id and c==1)
    end

  end

  def not_in_the_past
    errors.add_to_base("Can't sign up for a time slot that has already passed!") if self.start <= Time.now
  end

  def adjust_sub_requests
    self.sub_requests.each do |sub|
      if sub.start > self.end || sub.end < self.start
        sub.destroy
      else
        sub.start = self.start if sub.start < self.start
        sub.mandatory_start = self.start if sub.mandatory_start < self.start
        sub.end = self.end if sub.end > self.end
        sub.mandatory_end = self.end if sub.mandatory_end > self.end
        sub.save!
      end
    end
  end


  class << columns_hash['start']
    def type
      :datetime
    end
  end
end
