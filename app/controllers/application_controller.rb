# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  # almost everything we do is restricted to a department so we always load_department
  # feel free to skip_before_filter when desired
  before_filter :department_chooser
  before_filter :load_user_session
  before_filter CASClient::Frameworks::Rails::Filter, :if => Proc.new{|s| s.using_CAS?}, :except => 'access_denied'
  before_filter :login_check, :except => :access_denied
  before_filter :load_department
#  before_filter :load_user

  helper :layout # include all helpers, all the time
  helper_method :current_user
  helper_method :current_department

  filter_parameter_logging :password, :password_confirmation

  protect_from_forgery # See ActionController::RequestForgeryProtection for details

  $appconfig = AppConfig.first

  def access_denied
    text = "Access denied"
    text += "<br>Maybe you want to <a href=\"#{login_path}\">try logging in with built-in authentication</a>?" if $appconfig.login_options.include?('built-in')
    text += "<br>Maybe you want to go <a href=\"#{department_path(current_user.departments.first)}/users\">here</a>?" if current_user && current_user.departments
    render :text => text, :layout => true
  end

  def using_CAS?
    User.first && (!current_user || current_user.auth_type=='CAS') && $appconfig && $appconfig.login_options.include?('CAS')
  end

  protected
  def current_user
    @current_user ||= (
#    raise @user_session.login.to_s
    if @user_session
      @user_session.user
    elsif session[:cas_user]
      User.find_by_login(session[:cas_user])
    else
      nil
    end)
  end
  
  def current_department
    unless @current_department
      if current_user
        @current_department = Department.find_by_id(session[:department_id])
        unless @current_department
          @current_department = current_user.default_department
          session[:department_id] = @current_department.id
        end
      end
    end
    @current_department
  end


#    if params[:department_id] or session[:department_id]
#        @department ||= Department.find(params[:department_id] || session[:department_id])
#    elsif current_user and current_user.departments
#      @department = current_user.user_config.default_dept ? Department.find(current_user.user_config.default_dept) : current_user.departments[0]
#    elsif current_user and current_user.is_superuser?
#      @department = Department.first
#    end
#  end

  # Application-wide settings are stored in the only record in the app_configs table
#  def app_config
#    AppConfig.first
#  end

  def load_department
    if (params[:department_id])
      @department = Department.find_by_id(params[:department_id])
      if @department
        session[:department_id] = params[:department_id]
      end
    end
    @department ||= current_department

    # update department id in session if neccessary so that we can use shallow routes properly
#      if params[:department_id]
#        session[:department_id] = params[:department_id]
#        @department = Department.find_by_id(session[:department_id])
#      elsif session[:department_id]
#        @department = Department.find_by_id(session[:department_id])
#      elsif current_user and current_user.departments
#        @department = current_user.departments[0]
#      end
   # load @department variable, no need ||= because it's only called once at the start of controller
  end

  def load_user
    @current_user = @user_session.user || User.find_by_login(session[:cas_user]) || User.import_from_ldap(session[:cas_user], true)
  end

  def load_user_session
    @user_session = UserSession.find
  end

  def require_admin_of(obj)
    redirect_to(access_denied_path) unless current_user.is_admin_of?(obj)
  end

  # these are the authorization before_filters to use under controllers
  def require_department_admin
    redirect_to(access_denied_path) unless current_user.is_admin_of?(current_department)
  end

  def require_loc_group_admin(current_loc_group)
    redirect_to(access_denied_path) unless current_user.is_admin_of?(current_loc_group)
  end

  def require_superuser
    unless current_user.is_superuser?
      flash[:notice] = "That action is only available to superusers."
      redirect_to(access_denied_path)
    end
  end

  def login_check
  if !User.first
    redirect_to first_app_config_path
  elsif !current_user
      if $appconfig.login_options==['built-in'] #AppConfig.first.login_options_array.include?('built-in')
        redirect_to login_path
      else
        redirect_to access_denied_path
      end
    end
  end

  def redirect_with_flash(msg = nil, options = {:action => :index})
    if msg
      msg = msg.join("<br/>") if msg.is_a?(Array)
      flash[:notice] = msg
    end
    redirect_to options
  end

  private

  def department_chooser
    if (params[:su_mode] && current_user.superuser?)
      current_user.update_attribute(:supermode, params[:su_mode]=='ON')
      flash[:notice] = "Supermode is now #{current_user.supermode? ? 'ON' : 'OFF'}"
      redirect_to(root_path) and return
    end
    if (params["chooser"] && params["chooser"]["dept_id"])
      session[:department_id] = params["chooser"]["dept_id"]
      redirect_to switch_department_path and return
    end
  end


  
  #checks to see if the action should be rendered without a layout. optionally pass it another action/controller
  def layout_check(action = action_name, controller = controller_name)
     if params[:layout] == "false"
      render :controller => controller, :action => action, :layout => false
    end
  end

  # overwrite this method in other controller if you wanna go to a different url after chooser submit
  # it tries to find the index path of the current resource;
  # for example if you're in shifts_controller then it goes to shifts_path
  # however it won't work for some nested routes (and defaults to root_path instead) so please overwrite this method in such controller
  def switch_department_path
    send("#{controller_name}_path") rescue root_path
  end
end
