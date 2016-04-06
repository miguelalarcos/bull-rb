require 'time'

def resolve_times doc, keys
  keys.each do |k|
    d = doc
    ks = k.split('.')
    attr = ks.shift.to_sym
    while ks != []
      if d.is_a? Array
        d = d[attr.to_i]
      else
        d = d[attr]
      end
      attr = ks.shift.to_sym
    end
    begin
        i = Integer(attr.to_s)
        d[i] = Time.parse d[i]
    rescue
        d[attr] = Time.parse d[attr]
    end
  end
end

def encode_times doc, base=''
  ret = []
  if doc.is_a? Array
    doc.each_with_index { |v, i| ret << encode_times(v, base + '.' + i.to_s)}
  elsif doc.is_a? Hash
    doc.each_pair {|k, v| ret << encode_times(v, base + '.' + k.to_s)}
  elsif doc.is_a? Time
    return base[1..-1]
  end
  ret.flatten
end