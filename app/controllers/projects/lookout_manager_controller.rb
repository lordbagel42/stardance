class Projects::LookoutManagerController < ApplicationController
  before_action -> { head :not_found unless Flipper.enabled?(:lookout_manager, current_user) }
  before_action :set_project

  def index
    authorize @project, :create_devlog?

    @sessions = @project.lookout_sessions
                        .unassigned
                        .where(user: current_user)
                        .order(created_at: :desc)

    @hackatime_project_names = current_user.hackatime_projects
                                           .where.not(name: User::HackatimeProject::EXCLUDED_NAMES)
                                           .order(:name)
                                           .pluck(:name)
    @linked_hackatime_names = @hackatime_project_names & @project.hackatime_keys
    @default_hackatime_name = @project.hackatime_recorder_name
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end
end
