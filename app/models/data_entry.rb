class DataEntry < ActiveRecord::Base
  belongs_to :data_object

  validates_presence_of :data_object_id
  validates_presence_of :content
  
  
  # Write DataEntry content as a string with the following delimiters:
  #   Double semicolon between each datafield
  #   Double colon between the id of the datafield and the information it holds
  #   For datafields that themselves contain hashes:
  #     semicolons between each pair in the hash
  #     colons between keys and their associated values
  # ; and : in supplied content are escaped as **semicolon** and **colon**
  def write_content(fields)
    content = ""
    fields.each_pair do |key, value|
#      DataField.find(key).validate_content(value)    # awaiting implementation
      if value.class == HashWithIndifferentAccess || value.class == Hash
        content << key.to_s + "::"
        value.each_pair do |k,v|
          content << k.to_s + ":"
          content << v.to_s.gsub(";","**semicolon**").gsub(":","**colon**") + ";"
        end
        content.chomp!(";")          #strip off the last semicolon
        content << ";;"
      else
        content << key.to_s + "::"
        content << value.to_s.gsub(";","**semicolon**").gsub(":","**colon**") + ";;"
      end
    end
    self.content = content.chomp!(';;') #strip last double semicolon
  end

### Virtual attributes ###
  # Returns all the data fields referenced by a given data entry
  def data_fields
    self.content.split(';;').map{|str| str.split('::')}.map{|a| a.first}.sort
  end

  # Returns the data fields and user content in a set of {field => content} hashes
  def data_fields_with_contents
    content_arrays = self.content.split(';;').map{|str| str.split('::')}
    content_arrays.each do |a|
      if DataField.find(a.first).display_type == "check_box"
        checked = []
        a.second.split(';').each do |box|
          box = box.split(':')
          checked << box.first if box.second == "1"
        end
        a[1] = checked.join(', ') unless checked.empty?
      elsif DataField.find(a.first).display_type == "radio_button"
        box = a.second.split(':')
        a[1] = box.second if box.first == "1"
      end
    end
    content_arrays.sort!          # At this point, we have [field, content] arrays
    content_hash = {}
    content_arrays.each{|array| content_hash.store(array.first,array.second.gsub("**semicolon**",";").gsub("**colon**",":"))}     
    content_hash
  end

  def self.atlocation (location)
    DataEntry.all.select{|dataentry| dataentry.location == location }
  end

end