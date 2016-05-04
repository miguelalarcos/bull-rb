def i18n i18n_map, tag, count=nil
  if i18n_map.nil?
    return ''
  end
  doc_tag = i18n_map['map'][tag]
  if count
    doc_tag.each_pair do |k, v|
      range = k.split '..'
      if count >= range[0].to_i && count <= range[-1].to_i
        return v
      end
    end
  else
    doc_tag
  end
end