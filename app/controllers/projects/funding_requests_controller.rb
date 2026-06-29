class Projects::FundingRequestsController < ApplicationController
  before_action -> { head :not_found unless Flipper.enabled?(:hardware_flow, current_user) }
  before_action :set_project

  # Submitted from the "Submit Design to Get Project Funding" popup on the
  # project page. Creates a pending funding request for reviewer approval.
  def create
    authorize @project, :ship?

    @project.certification_funding_requests.create!(
      user: current_user,
      complexity_tier: params[:complexity_tier].to_i,
      requested_amount_cents: params[:requested_amount].to_i * 100,
      status: :pending
    )

    track_event "funding_requested", { project_id: @project.id, complexity_tier: params[:complexity_tier] }
    redirect_to project_path(@project),
                notice: "Design submitted for review! We'll get back to you soon."
  rescue ActiveRecord::RecordNotUnique
    redirect_to project_path(@project), alert: "You already have a design review in progress."
  rescue ActiveRecord::RecordInvalid => e
    redirect_back fallback_location: project_path(@project),
                  alert: e.record.errors.full_messages.to_sentence
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end
end
