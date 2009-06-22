require File.dirname(__FILE__) + '/../spec_helper'

module NoticeHelper
  def valid_notice_attributes
    {
      :author_id => 1,
#      :department_id => 1 ,
      :start_time => Time.now ,
      :end_time => nil ,
      :for_locations => 1 ,
      :for_location_groups => 1, 
    }
  end
end

describe Notice do
  include NoticeHelper

  before(:each) do
    @notice = Notice.new
  end

  it "should create a new instance given valid attributes" do
    @notice.attributes = valid_notice_attributes
    @notice.should be_valid
  end
  
  it "should have content" do
    @notice.content == nil?
  end

end
