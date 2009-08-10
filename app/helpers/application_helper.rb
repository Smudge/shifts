# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper

  def link_to_post_a_new_notice(report = false)
    report == true ? height = 200 : height = 445
    height = 540 if current_user.is_admin_of?(current_department)
    link_to_unless_current('Post a new notice', new_notice_path(:height => "#{height}", :width => 515), :title => "Post a new notice", :class => "thickbox")
  end

  def link_toggle(id, name, speed = "slow")
    # "<a href='#' onclick=\"Element.toggle('%s'); return false;\">%s</a>" % [id, name]
    link_to_function name, "$('##{id}').slideToggle('#{speed}')"
    # link_to_function name, "Effect.toggle('#{id}', 'appear', { duration: 0.3 });"
  end

  def early_late_info(start)
    now = Time.now
    m = distance_of_time_in_words(now - start)
    m += (now > start) ? " ago" : " later"
  end

  def user_has_active_shift?
    current_user.current_shift
  end

  def tokenized_users_autocomplete(object, field, id)
    json_string = ""
    unless object.nil? or field.nil?
      object.send(field).each do |user_source|
        json_string += "{name: '#{user_source.name}', id: '#{user_source.class}||#{user_source.id}'},\n"
      end
    end

    '<script type="text/javascript">
        $(document).ready(function() {
            $("#'+id+'").tokenInput("'+autocomplete_department_users_path(current_department)+'", {
                prePopulate: ['+json_string+'],
                classes: {
                    tokenList: "token-input-list-facebook",
                    token: "token-input-token-facebook",
                    tokenDelete: "token-input-delete-token-facebook",
                    selectedToken: "token-input-selected-token-facebook",
                    highlightedToken: "token-input-highlighted-token-facebook",
                    dropdown: "token-input-dropdown-facebook",
                    dropdownItem: "token-input-dropdown-item-facebook",
                    dropdownItem2: "token-input-dropdown-item2-facebook",
                    selectedDropdownItem: "token-input-selected-dropdown-item-facebook",
                    inputToken: "token-input-input-token-facebook"
                }
            });
        });
        </script>' + text_field_tag(id)
  end


  def select_integer (object, column, start, stop, default = nil)
    output = "<select id=\"#{object}_#{column}\" name=\"#{object}[#{column}]\">"
    for i in start..stop
      output << "\n<option value=\"#{i}\""
      output << " selected=\"selected\"" if i == default
      output << ">#{i}"
    end
    output + "</select>"
  end

  def unobtrusive_datepicker_includes
    javascript 'datepicker'
    stylesheet 'datepicker'
  end

  def unobtrusive_datepicker_include_tags
    (javascript_include_tag 'datepicker') + (stylesheet_link_tag 'datepicker')
  end

  def time_format
    '%I:%M%p'
  end

  def date_format
    '%B %d, %Y'
  end

  #requires a div with id "AJAX_status" to be included in the page
  def ajax_alert(page, content, delay_length = 2.5)
    rand = "rand"+rand(1000).to_s #unique id for element
    page.insert_html :top, "AJAX_status", "<div id='#{rand}' class='AJAX_alert'>#{content}</div>"
    page[rand].visual_effect :slide_down
    page[rand].visual_effect :highlight
    page.delay(delay_length) do
      page[rand].visual_effect :slide_up
    end
  end
end

