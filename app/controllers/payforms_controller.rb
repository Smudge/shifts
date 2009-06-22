class PayformsController < ApplicationController

  def index
    if current_user.is_admin_of?(current_department)
      @payforms =  current_department.payforms
    else
      @payforms =  current_department.payforms && current_user.payforms
    end
    if params[:unsubmitted]
      @payforms = @payforms.unsubmitted
    elsif params[:submitted]
      @payforms = @payforms.unapproved
    elsif params[:approved]
      @payforms = @payforms.unprinted
    elsif params[:printed]
      @payforms = @payforms.printed
    else
      params[:unsubmitted] = params[:submitted] = params[:approved] = true
      @payforms -= @payforms.printed
    end
    @payforms.sort! { |a,b| a.user.last_name <=> b.user.last_name }
  end

  def show
    @payform = Payform.find(params[:id])
    errors = []
    if !@payform
      errors << "Payform does not exist."
    end
    if !(@payform.user == current_user || current_user.is_admin_of?(current_department))
      errors << "You do not own this payform, and are not an admin of this deparment."
    end
    if @payform.department != current_department
      errors << "The payform (from "+@payform.department.name+") is not in this department ("+current_department.name+")."
    end
    if errors.length > 0
      flash[:error] = "Error: "+errors*"<br/>"
      redirect_to payforms_path
    else 
      respond_to do |show|
        show.html #show.html.erb
        show.pdf  #show.pdf.prawn
        show.csv do
          csv_string = FasterCSV.generate do |csv|
            csv << ["First Name", "Last Name", "Employee ID", "Start Date", "End Date", "Total Hours"]
            csv << [@payform.user.first_name, @payform.user.last_name, @payform.user.employee_id, @payform.start_date, @payform.date, @payform.hours]
          end
          send_data csv_string, :type => 'text/csv; charset=iso-8859-1; header=present', :disposition => "attachment; filename=users.csv"
        end
      end
    end
  end

  def go
    date = params[:date] ? params[:date].to_date : Date.today
    redirect_to Payform.build(current_department, current_user, date)
  end
  
  def prune
    @payforms = current_user.payforms & current_department.payforms
    @payforms.select{|p| p.payform_items.empty? }.map{|p| p.destroy }
    flash[:notice] = "Successfully pruned empty payforms."
    redirect_to payforms_path
  end
  
  def submit
    @payform = Payform.find(params[:id])
    @payform.submitted = Time.now
    if @payform.save
      flash[:notice] = "Successfully submitted payform."
    end
    redirect_to @payform
  end
  
  def approve
    @payform = Payform.find(params[:id])
    @payform.approved = Time.now
    @payform.approved_by = current_user
    if @payform.save
      flash[:notice] = "Successfully approved payform."
    end
    redirect_to @payform  
  end
  
  def print
    @payform = Payform.find(params[:id])
    # @payform.printed = Time.now
    if @payform.save
      flash[:notice] = "Printing is not implemented yet."
    end
    redirect_to @payform
  end

end

