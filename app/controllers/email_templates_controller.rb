class EmailTemplatesController < ApplicationController
  skip_before_action :show_pending_achievement_notifications!,
                     :initialize_cache_counters,
                     :track_active_user,
                     raise: false

  def show
    @template = EmailTemplate.find_by!(name: params[:name])
    @compiled_html = Mjml::Parser.new(@template.name, @template.body).render
    render "admin/email_templates/preview", layout: false
  end
end
