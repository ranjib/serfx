# encoding: UTF-8

module Serfx
  # Helper methods for string manipulation
  module Utils
    # snakecase to camelcase converter. Taken from chef
    # (mixin/convert_to_class_name.rb)
    def camel_case(str)
      str = str.dup
      str.gsub!(/[^A-Za-z0-9_]/, '_')
      rname = nil
      regexp = /^(.+?)(_(.+))?$/
      mn = str.match(regexp)
      if mn
        rname = mn[1].capitalize
        while mn && mn[3]
          mn = mn[3].match(regexp)
          rname << mn[1].capitalize if mn
        end
      end
      rname
    end
    # camelcase to snakecase converter
    def snake_case(str)
      str.gsub(/[A-Z]/) { |s| '_' + s }.downcase.sub(/^\_/, '')
    end
  end
end
