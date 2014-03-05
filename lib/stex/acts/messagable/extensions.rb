module Stex
  module Acts
    module Messagable
      module Extensions
        def self.included(base)
          base.class_eval do
            base.send :extend,  ClassMethods
          end
        end

        #----------------------------------------------------------------
        #                        Class Methods
        #----------------------------------------------------------------

        module ClassMethods
          def messagable?(recipient)
            Stex::Acts::Messagable.messagable?(recipient)
          end
        end

        #----------------------------------------------------------------
        #                      Instance Methods
        #----------------------------------------------------------------


        #
        # @return [Bool] +true+ if the notification was marked as read before
        #
        def read?
          read_at.present?
        end

        #
        # @see #read?
        #
        def unread?
          !read?
        end

        #
        # Sets the +read_at+ attribute to the current time
        # and saves the record without validations
        #
        def mark_as_read!
          self.read_at = Time.now
          save(false)
        end

        #----------------------------------------------------------------
        #                      Metadata Handling
        #----------------------------------------------------------------

        def url
          metadata[:url]
        end

        def url=(url)
          metadata[:url] = url
        end

        #
        # @return [Messagable]
        #   The additional recipients which were determined by the +send_message+ function
        #
        def additional_recipients
          meta_record_list(:additional_recipients)
        end

        #
        # Sets additional recipients in this message's metadata.
        # This is automatically done by the +send_message+ function.
        #
        # @param [Array<Messagable>] recipients
        #   The list of additional recipients
        #
        def additional_recipients=(recipients = [])
          meta_record_list_update(:additional_recipients, recipients)
        end

        #
        # @return [Array<String>]
        #   The +recipient_name+s of all additional recipients. This uses the
        #   +recipient_name+ option set in the recipient's model class.
        #
        def additional_recipient_names
          additional_recipients.map {|r| r.messagable_accessor(:recipient_name) }
        end

        #
        # @return [Array<Messagable>]
        #   The original recipients which were initially given to the
        #   +send_message+ function (so no derived recipients)
        #
        def original_recipients
          result = []
          metadata[:original_recipients].each do |recipient|

            #Optional recipients included
            if recipient.first.is_a?(Array)
              recipient_class, recipient_id = recipient.first
              result << [recipient_class.constantize.find(recipient_id), recipient.last]
            else
              recipient_class, recipient_id = recipient
              result << recipient_class.constantize.find(recipient_id)
            end
          end
          result
        end

        #
        # @return [Array<String>]
        #   The names of the +original_recipients+,
        #   uses the +recipient_name+ option set in the recipient's model class
        #
        def original_recipient_names
          original_recipients.map do |recipient_or_array|
            if recipient_or_array.is_a?(Array)
              recipient      = recipient_or_array.first
              optional_names = recipient_or_array.last.map {|i| recipient.messagable_accessor(:optional_recipients).assoc(i.to_sym).third }
              [recipient.messagable_accessor(:recipient_name), *optional_names]
            else
              recipient_or_array.messagable_accessor(:recipient_name)
            end
          end
        end

        #
        # Stores the original recipients of this notification.
        #
        # @param recipients
        #   An array of +Messagable+ which may also include optional recipients
        #   as symbols (see +{Stex::Acts::Messagable#send_notification}+)
        #
        def original_recipients=(recipients = [])
          result = []

          recipients.each do |recipient_or_array|
            if recipient_or_array.is_a?(Array)
              recipient = recipient_or_array.first
              result << [[recipient.class.to_s, recipient.id], recipient_or_array.last]
            else
              result << [recipient_or_array.class.to_s, recipient_or_array.id]
            end
          end

          metadata[:original_recipients] = result
        end

        private

        #
        # @private
        #
        def meta_record_list(key)
          return [] unless metadata[key]
          @meta_record_list ||= {}
          @meta_record_list[key] ||= metadata[key].map {|class_name, id| class_name.constantize.find(id)}
        end

        #
        # @private
        #
        def meta_record_list_update(key, list = [])
          @meta_record_list ||= {}
          @meta_record_list[key] = list
          metadata[key] = @meta_record_list[key].map {|r| [r.class.to_s, r.id] }
        end

        #
        # Accessor method for all metadata
        # Metadata can then be accessed using []
        #
        # @private
        #
        def metadata
          self.serialized_metadata ||= {}
        end
      end
    end
  end
end