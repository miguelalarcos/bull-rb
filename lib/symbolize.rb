def symbolize_keys obj
  if obj.is_a? Hash
    return obj.inject({}) {|memo, (k, v)| memo[k.to_sym]=symbolize_keys(v); memo}
  end
  if obj.is_a? Array
    return obj.map {|x| symbolize_keys x}
  end
  obj
end

