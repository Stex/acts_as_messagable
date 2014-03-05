require "acts_as_messagable/version"
require "stex/acts/messagable"
require "stex/acts/messagable/extensions"

ActiveRecord::Base.class_eval do
  include Stex::Acts::Messagable
end