# frozen_string_literal: true

module CustomFields
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    # Declares a custom field store on the given attrib_name.
    # Can be used on a PORO or AR model.
    # In both cases, the CustomFields::Instance lives in the @<attrib_name> instance variable.
    #
    # If AR is used, the underlying hash will be stored in the attribute using write_attribute.
    # If the AR attribute has an existing hash value, it will be used to initialize the Instance.
    # Any changes to the Instance via its accessors are stored directly in underlying hash,
    # so saving the AR model at any time will store a current copy of the data to the DB.
    def custom_fields(attrib_name, spec:)
      if respond_to?(:validate)
        validate do
          errors.add(attrib_name, :invalid) unless send(attrib_name).valid?
        end
      end

      i18n_key = respond_to?(:model_name) ? model_name.i18n_key : name.gsub(/(?<!\A)([A-Z])/, '_\1').downcase

      # The spec is fetched the first time it is needed and memoized at the instance level.
      define_method("#{attrib_name}_custom_fields_spec") do
        ivar_value = instance_variable_get("@#{attrib_name}_custom_fields_spec")
        return ivar_value unless ivar_value.nil?

        computed_spec = Spec.new(spec.call(self))
        instance_variable_set("@#{attrib_name}_custom_fields_spec", computed_spec)
      end

      define_method(attrib_name) do
        cur_instance = instance_variable_get("@#{attrib_name}")

        # If working with AR, ensure we have some kind of hash to start with.
        # If we create our own here using a literal and don't store it using `write_attribute`,
        # it won't be accessible by AR when persisting to the DB.
        self[attrib_name] = {} if respond_to?(:read_attribute) && self[attrib_name].nil?

        # If no instance exists in inst var, create an empty one.
        if cur_instance.nil?
          instance_variable_set("@#{attrib_name}", Instance.new(
            host: self,
            spec: send("#{attrib_name}_custom_fields_spec"),
            instance_data: respond_to?(:read_attribute) ? self[attrib_name] : {},
            model_i18n_key: i18n_key,
            attrib_name: attrib_name
          ))
        end

        instance_variable_get("@#{attrib_name}")
      end

      define_method("#{attrib_name}=") do |hash|
        cur_instance = instance_variable_get("@#{attrib_name}")
        if cur_instance.is_a?(Instance)
          cur_instance.update(hash)
        else
          cur_instance = Instance.new(
            host: self,
            spec: send("#{attrib_name}_custom_fields_spec"),
            instance_data: hash,
            model_i18n_key: i18n_key,
            attrib_name: attrib_name
          )
          instance_variable_set("@#{attrib_name}", cur_instance)
        end
      end

      # reload uses attributes= which bypasses our setters above.
      # So we need to intercept and run update manually.
      define_method("reload") do |options = nil|
        result = super(options)
        send("#{attrib_name}=", self[attrib_name])
        result
      end
    end
  end

  class ReservedKeyError < StandardError; end
end
