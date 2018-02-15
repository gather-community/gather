class ApplicationLens < Lens::Lens
  def self.param_name(name = nil)
    if name
      class_variable_set('@@param_name', name)
    else
      class_variable_get('@@param_name')
    end
  end

  def param_name
    self.class.param_name
  end
end
