class PayformItemSet < ActiveRecord::Base

  has_many :payform_items
  belongs_to :category
  delegate :department, :to => :category
  validates_presence_of :description, :hours, :date, :category_id
  validate :payform_item_creation

private
  def payform_item_creation
    errors.add("Users did not add properly.", "") if PayformItem.find_by_payform_item_set_id(self.id) == nil
  end


end

