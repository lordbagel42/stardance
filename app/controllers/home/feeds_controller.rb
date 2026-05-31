class Home::FeedsController < ApplicationController
  include OnboardingResumable

  skip_before_action :remember_page
  before_action :resume_or_expire_onboarding!

  def show
    authorize :home, :feed?
    load_feed
    load_recommended_projects
    render layout: false
  end

  private

  def load_feed
    devlogs = Post.of_devlogs(join: true)
                  .visible_to(current_user)
                  .where(post_devlogs: { deleted_at: nil })
                  .where(project_id: Project.not_deleted)
                  .includes(:user, :project)
                  .preload(postable: [ :post, :attachments_attachments ])
                  .order(created_at: :desc)
                  .limit(20)

    ship_events = Post.of_ship_events(join: true)
                      .visible_to(current_user)
                      .where.not(post_ship_events: { certification_status: "rejected" })
                      .where(project_id: Project.not_deleted)
                      .includes(:user, :project, postable: { mission_submission: :mission })
                      .order(created_at: :desc)
                      .limit(20)

    reposts = Post.of_reposts(join: true)
                  .visible_to(current_user)
                  .where(post_reposts: { deleted_at: nil })
                  .includes(
                    :user,
                    postable: {
                      original_post: [
                        :user,
                        :project,
                        { postable: [ :post, :attachments_attachments ] }
                      ]
                    }
                  )
                  .order(created_at: :desc)
                  .limit(20)
                  .select { |post| post.visible_repost_original_for?(current_user) }

    all_posts = (devlogs.to_a + ship_events.to_a + reposts)
                  .sort_by { |p| -p.created_at.to_i }
                  .first(20)

    @feed_posts = all_posts.select { |post| post.postable.present? }
    @liked_devlog_ids = liked_devlog_ids_for(@feed_posts)
  end

  def liked_devlog_ids_for(posts)
    devlog_posts = posts.select { |p| p.postable_type == "Post::Devlog" }
    return Set.new if devlog_posts.empty?

    Like.where(user: current_user, likeable_type: "Post::Devlog", likeable_id: devlog_posts.map(&:postable_id)).pluck(:likeable_id).to_set
  end

  def load_recommended_projects
    @recommended_projects = Project.excluding_member(current_user)
                                   .where(deleted_at: nil)
                                   .with_banner_priority
                                   .limit(6)
  end
end
