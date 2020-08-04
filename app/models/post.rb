# frozen_string_literal: true

module Communitarian
  refine Post do
    def resolution?
      self.topic.custom_fields["is_resolution"]
    end
  end
end
