Given /^I have a payform for the week "([^\"]*)"$/ do |week|
  date = week.to_date
  payform = Payform.create!(:date => date,
                            :user_id => @user.id,
                            :department_id => @department.id,
#    I've hard-coded this, but we sould find a more elegant way to do it -cmk49'
                            :id => "1")
end

Given /^I have the following payform items?$/ do |table|
  table.hashes.each do |row|
    category = Category.find_by_name(row[:category])
    user = User.find_by_login(row[:user_login])
    #    I've hard-coded this, but we sould find a more elegant way to do it -cmk49'
    payform = Payform.find(1)
    PayformItem.create!(:category_id => category.id,
                    :user_id => user.id,
                    :hours => row[:hours].to_f,
                    :description => row[:description],
                    :date => Time.parse(row[:date]),
                    :payform_id => payform.id)
  end

end

Given /^I have the following payforms?:$/ do |table|
  table.hashes.each do |row|

    date = row[:date].to_date
    department = Department.find_by_name(row[:department])
    user = User.find(:first, :conditions => {:first_name => row[:user_first], :last_name => row[:user_last]})
    submitted = row[:submitted] == "true" ? Time.now - 180 : nil
    approved = row[:approved] == "true" ? Time.now - 120 : nil
    printed = row[:printed] == "true" ? Time.now - 60 : nil

    Payform.create!(:date => date , :department_id => department.id,
                    :user_id => user.id, :submitted => submitted,
                    :approved => approved, :printed => printed)
  end
end

Then /^payform item ([0-9]+) should be a child of payform item ([0-9]+)$/ do |id_1, id_2|
  payform_item_1 = PayformItem.find(id_1.to_i)
  payform_item_2 = PayformItem.find(id_2.to_i)
  payform_item_2.payform_item_id.should == payform_item_1.id
end

Then /^payform item ([0-9]+) should have attribute (.+) "([^\"]*)"$/ do |id, attribute, expected|
  payform_item = PayformItem.find(id.to_i)
  attribute_constant = attribute.constantize
  payform_item.attribute_constant.should match(expected)
end


Then /^the payform should be submitted$/ do
  @user.payforms.first.submitted.should_not be_nil
end

Then /^I should see "([^\"]*)" under "([^\"]*)" in column ([0-9]+)$/ do |expected_message, header, column|
  assert_select("table") do
    assert_select("th td:nth-of-type(#{column.to_i})", header)
    assert_select("tr td:nth-of-type(#{column.to_i})", expected_message)
  end
end

Then /^"([^\"]*)" should have ([0-9]+) payforms?$/ do |user, count|
  User.find_by_name(user).payforms.should have(count.to_i).payforms

Then /^the user "([^\"]*)" should have ([0-9]+) payform_item$/ do |user, count|
  @user = User.find_by_login(user).id
  PayformItem.find(:conditions => {:user_id => user}).count.should == count.to_i
end
