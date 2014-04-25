# encoding: UTF-8

module Serfx
  module Utils
    # shamelessly taken from chef :-)
    # https://github.com/opscode/chef/blob/master/lib/chef/mixin/convert_to_class_name.rb
    def camel_case(str)
      str = str.dup
      str.gsub!(/[^A-Za-z0-9_]/,'_')
      rname = nil
      regexp = %r{^(.+?)(_(.+))?$}
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

    def snake_case(str)
      str.gsub(/[A-Z]/) {|s| "_" + s}.downcase.sub(/^\_/, "")
    end
  end
end
