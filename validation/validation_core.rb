module Validate

  def attrs
    @attrs ||= {}
  end

  def field hsh
    attrs.merge! hsh
  end

  if RUBY_ENGINE == 'opal'

    def validate state
      dct = state_to_hash(state)
      ret = []
      dct.each_pair do |k, v|
        if ['id', 'u_timestamp', 'i_timestamp', 'owner'].include? k
          next
        end
        #return false if !v.nil? && !v.is_a?(attrs[k])
        if !v.nil? && !v.is_a?(attrs[k])
          val = false
        elsif respond_to? 'is_valid_' + k + '?'
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

  else

    def validate dct
      dct.each_pair do |k, v|
        k = k.to_s
        if ['id', 'u_timestamp', 'i_timestamp', 'owner'].include? k
          next
        end
        return false if !v.nil? && !v.is_a?(attrs[k])
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
    attrs.keys.each do |attr|
      ret[attr] = state.__send__ attr
    end
    ret
  end
end

