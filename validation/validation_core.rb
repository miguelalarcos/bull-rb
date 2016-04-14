module Validate

  def attrs
    @attrs ||= {}
  end

  def field hsh
    attrs.merge! hsh
  end

  def validate_ dct
    ret = []
    attrs.each_key do |k|
      if ['id', 'u_timestamp', 'i_timestamp', 'owner'].include? k
        next
      end
      v = get_value_nested k, dct
      k_r = k.gsub('.', '_')
      if !v.nil? && !v.is_a?(attrs[k])
        val = false
      elsif respond_to? 'is_valid_' + k_r + '?'
        begin
          val = send('is_valid_' + k_r + '?', v, dct)
        rescue
          val = false
        end
      else
        val=true
      end
      ret << val
      yield k_r, val if !val.nil?
    end
    ret
  end

  if RUBY_ENGINE == 'opal'

    def validate state
      ret = validate_(state_to_hash(state)){|k, v| state.__send__('is_valid_' + k + '!', v)}
      state.is_valid! ret.all?
    end

    #def is_value_in_refs?(attr)
    #  @refs[attr]
    #end

  else

    #def is_value_in_refs?(attr)
    #  return true

    def validate dct
      attrs.each_key do |k|
        if ['id', 'u_timestamp', 'i_timestamp', 'owner'].include? k
          next
        end
        v = get_value_nested k, dct

        return false if !v.nil? && !v.is_a?(attrs[k])
        k = k.gsub('.', '_')
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
  end

  def state_to_hash state
    ret = {}
    aux = attrs.keys.map{|x| x.split('.')[0]}.uniq
    aux.each do |attr|
      ret[attr] = state.__send__ attr
    end
    ret
  end

  def get_value_nested k, dct
    value = dct
    for k in k.split('.')
      value = value[k.to_sym]
      return nil if value.nil?
    end
    value
  end
end

