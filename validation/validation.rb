module Validate
  def validate state
    dct = state_to_hash(state)
    ret = []
    dct.each_pair do |k, v|
      val = send('is_valid_' + k.to_s + '?', v, dct)
      state.__send__('is_valid_' + k.to_s + '!', val)
      ret << val
    end
    state.is_valid! ret.all?
  end

  def validate_update dct
    ret = []
    dct.each_pair do |k, v|
      val = send 'is_valid_' + k.to_s + '?', v, dct
      ret << val
    end
    ret.all?
  end

  def validate_insert dct
    ret = []
    to_validate.each do |attr|
      val = send 'is_valid_' + attr.to_s + '?', dct[attr], dct
      ret << val
    end
    ret.all?
  end

  def state_to_hash state
    ret = {}
    to_validate.each do |attr|
      ret[attr] = state.__send__ attr.to_s
    end
    ret
  end

  def to_validate
    []
  end
end

class ValidateCar
  include Validate

  def to_validate
    ['registration']
  end

  def is_valid_registration? (value, doc)
    if doc['wheels'] <= 4
      value.start_with? 'A'
    else
      value.start_with? 'B'
    end
  end
end