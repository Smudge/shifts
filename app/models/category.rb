class Category < ActiveRecord::Base
  belongs_to :department
  has_many :payform_items

  validates_presence_of :name, :department_id
  validates_uniqueness_of :name, :scope => :department_id
  
  named_scope :disabled, :conditions => { :active   => false }
  named_scope :active,   :conditions => { :active   => true  }
  named_scope :built_in, :conditions => { :built_in => true  }
  named_scope :usable,   :conditions => { :active   => true, :built_in => false }
  
  def self.enabled
    Category.find(:all, :conditions => ['active = ?', true])
  end
  
  protected
  
  
end

