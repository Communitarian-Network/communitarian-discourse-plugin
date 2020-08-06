# frozen_string_literal: true

module Jobs
  class ReopenResolution < ::Jobs::Base
    def execute(args)
      raise Discourse::InvalidParameters.new(:post_id) if args[:post_id].blank?

      post = Post.find(args[:post_id])
      Communitarian::Resolution.new(Communitarian::ResolutionSchedule.new).
        reopen_weekly_resolution!(post)
    end
  end
end
