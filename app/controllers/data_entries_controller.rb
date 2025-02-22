class DataEntriesController < ApplicationController

  before_filter :check_for_data_object

  def new
    @data_entry = DataEntry.new
    @data_object = DataObject.find(params[:data_object_id])
    @thickbox = true if params[:layout] == "false"
    layout_check
  end

  def create
    @data_entry = DataEntry.new({:data_object_id => params[:data_object_id]})
    #TODO: Fix this bug related to current_user.current_shift /.report
    unless current_user.current_shift && current_user.current_shift.report.data_objects.include?(@data_entry.data_object)
      flash[:error] = "You are not signed into a shift."
      redirect_to(access_denied_path) and return false
    end
    @data_entry.write_content(params[:data_fields])

    if @data_entry.save
      flash[:notice] = "Successfully updated #{@data_entry.data_object.name}."
      if @report = current_user.current_shift.report
        content = []
        @data_entry.data_fields_with_contents.each {|entry| content.push("#{DataField.find(entry.first).name.humanize}: #{entry.second}")}
        @report.report_items << ReportItem.new(:time => Time.now, :content => "Updated #{@data_entry.data_object.name}: #{"\n"} #{content.join("\n")}", :ip_address => request.remote_ip)
      end
    else
      flash[:error] = "Could not update #{@data_entry.data_object.name}."
    end
    respond_to do |format|
      format.js
      format.html {redirect_to @report ? @report : @data_entry.data_object}
    end
  end

## Are we removing this feature?
#  def edit
#    @data_entry = DataEntry.find(params[:id])
#    @data_object = DataObject.find(params[:data_object_id])
#  end
#
#  def update
#    @data_entry = DataEntry.find(params[:id])
#    if @data_entry.update_attributes(params[:data_entry])
#      flash[:notice] = "Successfully updated data entry."
#      redirect_to data_object_path(params[:data_object_id])
#    else
#      render :action => 'edit'
#    end
#  end

  private

  def check_for_data_object
    unless params[:data_object_id]
      flash[:error] = "You must specify a data object before viewing associated data fields."
      redirect_to data_objects_path
    end
  end
end

