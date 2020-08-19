# frozen_string_literal: true

module Communitarian
  class UniqueUsername
    attr_reader :name, :id

    def initialize(user)
      @name = user[:name]
      @id = user[:id]
    end

    def to_s
      @username ||= name && ActiveSupport::Inflector.transliterate(name)
        .downcase
        .+(".#{id}").gsub(/-+/, "0")
        .gsub(/\W+/, ".")
    end
  end
end
