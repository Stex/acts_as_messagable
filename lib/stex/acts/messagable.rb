module Stex
  module Acts
    module Messagable
      def self.messagable?(model)
        model.respond_to?(:acts_as_messagable_options)
      end

      def self.message_class=(klass)
        @@message_class_name = klass.to_s
      end

      def self.message_class
        @@message_class_name.classify.constantize
      end

      def self.message_class_name
        @@message_class_name.classify
      end

      def self.run_method(instance, proc_or_symbol, default = nil)
        if proc_or_symbol.is_a?(Symbol) || proc_or_symbol.is_a?(String)
          raise Exception.new("Expected #{proc_or_symbol} to be an instance method of #{instance.class.name}") unless instance.respond_to?(proc_or_symbol)
          instance.send(proc_or_symbol)
        elsif proc_or_symbol.is_a?(Proc)
          proc_or_symbol.call(instance)
        else
          default
        end
      end

      #
      # Follows possible forward and optional recipient chains down
      # to the white rabb... final recipient which then either handles
      # the message hash or receives a message through the system
      #
      # @param [Array<Messagable>] recipients
      #   recipients to be inspected
      #
      # @return [Array<Messagable>]
      #   Messagables which do not have a +:forward+-option set.
      #
      def self.determine_message_recipients(recipients = [])
        result = []

        Array(recipients).each do |recipient_or_array|

          #Determine optional recipients and add them to the result set
          if recipient_or_array.is_a?(Array)
            recipient           = recipient_or_array.first
            optional_recipients = Array(recipient_or_array.last).map { |i| recipient.messagable_accessor(:optional_recipients).assoc(i.to_sym).second }.flatten

            result += determine_message_recipients(optional_recipients)
          else
            recipient = recipient_or_array
          end

          raise ArgumentError.new('Invalid Recipient: ' + recipient.inspect) unless Stex::Acts::Messagable.messagable?(recipient)

          #Handle +forward_to+ options on the recipient record.
          #If it's set, we don't want to add the current recipient to the result list,
          #but rather the ones it's pointing at.
          if recipient.messagable_accessor(:forward_to)
            result += determine_message_recipients(recipient.messagable_accessor(:forward_to))
          else
            result << recipient
          end
        end

        result
      end

      def self.included(base)
        base.class_eval do
          base.send :extend, ClassMethods
        end
      end

      module ClassMethods
        #
        # Adds the functionality to send and receive messages to this +ActiveRecord+ class
        #
        # @param [Hash] options
        #   Available Options and overrides for this model class
        #
        # @option options [Proc, Symbol] :sender_name ("Class.human_name #self.id")
        #   Proc or Proc Name to determine the sender name.
        #
        # @option options [Proc, Symbol] :recipient_name ("Class.human_name #self.id")
        #   Proc or Instance Method Name to determine the recipient name.
        #
        # @option options [Proc, Symbol] :forward_to
        #   Proc or Instance Method Name. If specified, the system will forward
        #   received messages to the method's return value instead of to
        #   the actual record
        #
        # @option options [Array<Array<Symbol, Proc|Symbol, String>>] :optional_recipients
        #   One ore more recipients that may be included in a message
        #   to an instance of this class. These should be selectable on the view part
        #   of the application, e.g. checkboxes next to the actual recipient.
        #   The elements are used as follows:
        #
        #   1. An identifier to access this optional recipient group,
        #   2. The actual selector that should return the recipients,
        #   3. A string or Proc that tells the system how to display this optional recipient
        #
        # @option options [Proc, Symbol] :handler
        #   If given, messages are sent to the given proc object / instance method instead of
        #   actually created in the database.
        #   The handler method has to accept 2 arguments, the message sender and a +Hash+ of options
        #   These options include:
        #   - :subject
        #   - :content
        #   - :additional_recipients (optional)
        #
        # @option options [Bool, Symbol, Proc] :store_additional_recipients
        #   If set or evaluating to +true+, all recipients (CC) are stored in a +Message+ record.
        #   This might make sense in cases when e.g. an email should contain a list of
        #   all the people that received it.
        #   If the value is a Symbol, the system will assume that there is an instance method with that name.
        #
        # @example Forwarding group messages to its students and optionally include the tutors
        #   acts_as_messagable :forward_to          => :students,
        #                      :optional_recipients => [[:tutors, lambda { |r| r.tutors }, Tutor.human_name(:count => 2)]]
        #   # The selector could simplified by +:tutors+ instead of the lambda expression
        #
        def acts_as_messagable(options = {})
          #Add has_many associations for easy message management
          klass = Stex::Acts::Messagable.message_class_name

          has_many :received_messages, :class_name => klass, :as => :recipient, :conditions => {:sender_copy => false}
          has_many :unread_messages, :class_name => klass, :as => :recipient, :conditions => {:read_at => nil, :sender_copy => false}
          has_many :read_messages, :class_name => klass, :as => :recipient, :conditions => ['read_at IS NOT NULL AND sender_copy = ?', false]
          has_many :sent_messages, :class_name => klass, :as => :sender, :conditions => {:sender_copy => true}

          cattr_accessor :acts_as_messagable_options

          coptions                       = {}

          #Sender and recipient procs
          coptions[:sender_name]         = options[:sender_name] || lambda { |r| "#{r.class.human_name}: #{r.id}" }
          coptions[:recipient_name]      = options[:recipient_name] || lambda { |r| "#{r.class.human_name}: #{r.id}" }

          #Forward and message handler proc
          coptions[:forward_to]          = options[:forward_to] if options.has_key?(:forward_to)
          coptions[:handler]             = options[:handler] if options.has_key?(:handler)

          #optional recipients
          coptions[:optional_recipients] = options[:optional_recipients] if options[:optional_recipients]

          coptions[:store_additional_recipients] = options[:store_additional_recipients]

          self.acts_as_messagable_options = coptions.freeze

          include Stex::Acts::Messagable::InstanceMethods
        end
      end

      module InstanceMethods

        #
        # Accessor for acts_as_messagable options and helpers
        #
        # @param [String, Symbol] request
        #   Requested option or helper, available values are:
        #   - +:sender_name+ Returns a formatted representation of +self+
        #     which is used in message sender display fields
        #
        #   - +:recipient_name+ Returns a formatted representation of +self+
        #     which is used in message recipient display fields
        #
        #   - +:forward_to+ Returns the recipient(s) a message should be forwarded
        #     to instead of being delivered to +self+ or +nil+ if not defined (see #acts_as_messagable)
        #
        #   - +:optional_recipients+ Returns an Array of Array<Symbol, *Messagable, String>,
        #     for more details see #acts_as_messagable
        #
        #   - +:store_additional_recipients+ Returns true|false, depending on the given option
        #     in #acts_as_messagable
        #
        def messagable_accessor(request)
          @cached_accessors ||= {}
          options           = self.class.acts_as_messagable_options

          @cached_accessors[request.to_sym] ||= case request.to_sym
                                                  when :sender_name
                                                    Stex::Acts::Messagable.run_method(self, options[:sender_name])
                                                  when :recipient_name
                                                    Stex::Acts::Messagable.run_method(self, options[:recipient_name])
                                                  when :forward_to
                                                    Stex::Acts::Messagable.run_method(self, options[:forward_to])
                                                  when :optional_recipients
                                                    Array(options[:optional_recipients]).map do |identifier, proc, name|
                                                      recipient_name = name.is_a?(String) ? name : Stex::Acts::Messagable.run_method(self, name)
                                                      [identifier, Stex::Acts::Messagable.run_method(self, proc), recipient_name]
                                                    end
                                                  when :store_additional_recipients
                                                    Stex::Acts::Messagable.run_method(self, options[:store_additional_recipients],
                                                                                      options[:store_additional_recipients])
                                                  else
                                                    raise ArgumentError.new('Invalid Request Argument: ' + request.to_s)
                                                end
        end

        #
        # Sends a message from +self+ to the given list of recipients
        # The whole sending happens in a transaction, so if one message creation
        # fails, none of them are sent.
        #
        # @param [Array<Messagable>|Array<Hash>|Messagable] recipients
        #   The message recipient(s), all have to be +messagable+
        #   The value will be handled as an Array in every case, so if you only
        #   have one recipient, you don't have to put it in brackets.
        #   The array elements may either be +messagable+ objects or arrays,
        #   mapping +messagable+ to Array<optional recipient identifiers>, see example.
        #
        # @param [String] subject
        #   The message message's subject
        #
        # @param [String] content
        #   The message message
        #
        # @example Recipient with optional recipient (see #acts_as_messagable)
        #   my_user.send_message([[my_group, [:tutors]]], 'Subject', 'Body')
        #
        def send_message(recipients, subject, content, options = {})
          recipients_with_cause = []
          all_recipients        = []

          #Create a new list of recipients together with the original recipients
          #that caused their existance in this list.
          #Also, determine whether additional recipients should be saved or not
          Array(recipients).each do |recipient_or_array|
            local_recipients = Stex::Acts::Messagable.determine_message_recipients([recipient_or_array])
            recipient        = recipient_or_array.is_a?(Array) ? recipient_or_array.first : recipient_or_array

            all_recipients += local_recipients

            recipients_with_cause << {:cause             => recipient,
                                      :store_additionals => recipient.class.acts_as_messagable_options[:store_additional_recipients] && local_recipients.size > 1,
                                      :recipients        => local_recipients.uniq}

          end

          all_recipients.uniq!
          processed_recipients = []

          Stex::Acts::Messagable.message_class.transaction do
            recipients_with_cause.each do |recipient_data|
              recipient_data[:recipients].each do |recipient|

                next if processed_recipients.include?(recipient)
                processed_recipients << recipient

                message                       = options.clone
                message[:subject]             = subject
                message[:content]             = content
                message[:original_recipients] = Array(recipients)

                #If the original recipient was set to store additional recipients, we store
                #all recipients that were caused by the same original recipient
                if recipient_data[:store_additionals]
                  message[:additional_recipients] = recipient_data[:recipients] - [recipient]
                  # If the recipient itself was set to store additional recipients, we store
                  # all recipients this message is sent to, regardless of the original recipients
                elsif recipient.class.acts_as_messagable_options[:store_additional_recipients] && final_recipients.size > 1
                  message[:additional_recipients] = all_recipients - [recipient]
                end

                #It might happen that a messagable does not actually want to
                #receive messages, but instead do something different.
                if recipient.class.acts_as_messagable_options[:handler]
                  recipient.class.acts_as_messagable_options[:handler].call(self, message)
                else
                  #Otherwise, a new message is created and sent to the given recipient
                  Stex::Acts::Messagable.message_class.create!(message.merge({:sender => self, :recipient => recipient}))
                end
              end
            end

            #Create a copy of the message for the sender
            Stex::Acts::Messagable.message_class.create!(:subject               => subject,
                                                         :content               => content,
                                                         :original_recipients   => Array(recipients),
                                                         :additional_recipients => all_recipients,
                                                         :sender                => self,
                                                         :recipient             => self,
                                                         :sender_copy           => true)
          end
        end
      end
    end
  end
end