module ClassesInput
  def valid_class
    return '' if params.valid.nil?
    if params.valid
      'input-successful'
    else
      'input-incorrect'
    end
  end

  def dirty_class
    if params.dirty
      'input-dirty'
    else
      ''
    end
  end
end