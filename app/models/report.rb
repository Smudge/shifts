class Report < ActiveRecord::Base
  belongs_to :shift
  delegate :user, :to => :shift
  delegate :location, :to => :shift
  has_many :report_items, :dependent => :destroy

  validates_uniqueness_of :shift_id

  def get_notices
    all_notices = self.shift.location.notices + self.shift.user.notices
    all_notices.uniq
  end

  def data_entries
    shift.location.data_objects.collect{|d| d.data_entries}.flatten.uniq
  end
  

end

