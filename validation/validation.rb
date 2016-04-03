#require 'time'

module Validate

  def attrs
    @attrs ||= {}
  end

  def field hsh
    attrs.merge! hsh
  end

  def validate state
    dct = state_to_hash(state)
    ret = []
    dct.each_pair do |k, v|
      if ['id', 'u_timestamp', 'i_timestamp', 'owner'].include? k
        next
      end
      return false if !v.is_a? attrs[k]
      if respond_to? 'is_valid_' + k + '?'
        begin
          val = send('is_valid_' + k + '?', v, dct)
        rescue
          val = false
        end
        state.__send__('is_valid_' + k + '!', val)
        ret << val
      end
    end
    state.is_valid! ret.all?
  end

  def validate_server_side dct
    dct.each_pair do |k, v|
      k = k.to_s
      if ['id', 'u_timestamp', 'i_timestamp', 'owner'].include? k
        next
      end
      return false if !v.is_a? attrs[k]
      if respond_to? 'is_valid_' + k + '?'
        begin
          b = send 'is_valid_' + k + '?', v, dct
        rescue
          b = false
        end
        return false if !b
      end
    end
    true
  end

  def state_to_hash state
    ret = {}
    attrs.keys.each do |attr|
      ret[attr] = state.__send__ attr
    end
    ret
  end
end

class ValidateCar
  include Validate

  def initialize
    field 'registration' => String
    field 'color' => String
    field 'wheels' => Integer
    field 'date' => Time
  end

  def is_valid_registration? (value, doc)
    if doc['wheels'] <= 4
      value.start_with? 'A'
    else
      value.start_with? 'B'
    end
  end
end