class ReportItemsController < ApplicationController
# Commented out all unnecessary actions -ben
#  def index
#    @report_items = ReportItem.all
#  end

#  def show
#    @report_item = ReportItem.find(params[:id])
#  end

#  def new
#    @report_item = ReportItem.new
#  end

  def create
    @report_item = ReportItem.new(params[:report_item])
    @report_item.time = Time.now
    @report_item.ip_address = request.remote_ip
    #if ip has changed from previous line item, note this
    previous_report_items = Report.find(params[:report_id]).report_items
    @report_item.content += " [IP Address changed to #{@report_item.ip_address}]" if(previous_report_items and previous_report_items[-1].ip_address != @report_item.ip_address)
    @report_item.report = params[:report_id] ? Report.find(params[:report_id]) : Shift.find(params[:shift_id]).report
    respond_to do |format|
      if current_user==@report_item.user && @report_item.save
        @report = Report.find(@report_item.report_id)
        format.html {redirect_to @report}
        format.js
      else
        flash[:notice] = "You can't add things to someone else's report!" if @report_item.user != current_user
        redirect_to @report_item.report
      end
    end
  end

#  def edit
#    @report_item = ReportItem.find(params[:id])
#  end

#  def update
#    @report_item = ReportItem.find(params[:id])
#    if @report_item.update_attributes(params[:report_item])
#      flash[:notice] = "Successfully updated report item."
#      redirect_to @report_item
#    else
#      render :action => 'edit'
#    end
#  end

#  def destroy
#    @report_item = ReportItem.find(params[:id])
#    @report_item.destroy
#    flash[:notice] = "Successfully destroyed report item."
#    redirect_to shift_report_report_items_url(@report_item.report.shift)
#  end
end

