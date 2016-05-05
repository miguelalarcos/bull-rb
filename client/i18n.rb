def i18n i18n_map, tag, count=nil
  if i18n_map.nil?
    return ''
  end
  begin
    doc_tag = i18n_map['map'][tag]
  rescue
    return ''
  end
  if count
    doc_tag.each_pair do |k, v|
      range = k.split '..'
      if range.length == 2 and range[0] != ''
        if count >= range[0].to_i && count <= range[-1].to_i
          return v
        end
      elsif range.length == 2 and range[0] == ''
        return v if count <= range[-1].to_i
      else
        return v if count >= range[0].to_i
      end
    end
  else
    doc_tag
  end
end