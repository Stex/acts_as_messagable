ActsAsMessagable
================

ActsAsMessagable is a gem to help you with internal messages
between `ActiveRecord::Base` instances in your Rails application.

A typical use case would be message system for the communication
between users, including replies, sender copies and an archive functionality.

It is also possible to send messages to instances of `ActiveRecord::Base`
which do not receive the messages themselves, but instead either
forward them to a group of other instances (which may forward them further)
or handle them in a specified method.

This makes the gem usable as an internal email replacement as well
as a notification system.

Installation
------------

Add this line to your application's Gemfile:

    gem 'acts_as_messagable'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install acts_as_messagable

Compatibility
-------------

Currently, the gem is compatible with Rails 2.3,
an upgrade to Rails 3 is planned.

Usage
-----

To declare a model as `messagable`, the gem adds a method
`acts_as_messagable` to all model classes.

The following lines will make all instances of `User` `messagable`,
meaning that Users may receive messages directly without further
processing them.

    class User < ActiveRecord::Base
        acts_as_messagable :sender_name    => lambda {|u| u.name :title },
                           :recipient_name => lambda {|u| u.name :title }
    end

Contributing
------------

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
