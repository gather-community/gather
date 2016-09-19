# Models a set of parameters and parameter values that scope an index view.
class Lens
  attr_accessor :fields, :params, :values

  # Gets the last explicit path for the given controller and action.
  # `context` - The calling view.
  def self.path_for(context:, controller:, action:)
    context.session["lenses"].try(:[], controller).try(:[], action).try(:[], "_path")
  end

  # `context` - The calling controller.
  # `fields` - The names of the fields that make up the lens, e.g. [:community, :search].
  # `params` - The Rails params hash.
  def initialize(context:, fields:, params:)
    self.fields = fields

    # Prepare the store.
    store = (context.session[:lenses] ||= {})
    store[context.controller_name] ||= {}
    self.values = (store[context.controller_name][context.action_name] ||= {})

    # Copy lens params from the params hash.
    fields.each do |f|
      self[f] = params[f] if params.has_key?(f)
    end

    # Save the path if parms explictly given, but clear path if all params are blank.
    if (params.keys & fields.map(&:to_s)).present?
      if params.slice(*fields).values.all?(&:blank?)
        delete(:_path)
      else
        self[:_path] = context.request.fullpath.gsub(/(&\w+=\z|\w+=&)/, "")
      end
    end
  end

  def blank?
    fields.none? { |f| self[f].present? }
  end

  def [](key)
    # Convert to string because the session hash uses strings.
    values[key.to_s]
  end

  def []=(key, value)
    values[key.to_s] = value
  end

  def delete(key)
    self.values.delete(key.to_s)
  end
end
