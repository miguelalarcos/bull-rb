def set_nested attr, value, doc
  path = attr.split '.'
  root = path.shift
  if path.empty?
    yield root, value
  else
    doc = doc[root] || {}
    while !path.empty?
      aux = path.shift
      if path.empty?
        doc[aux] = value
      else
        doc[aux] = {}
        doc = doc[aux]
      end
    end
    yield root, doc
  end
end

def get_nested! ret, attr
  ret_ = ret
  path = attr.split '.'
  root = path.shift
  doc = {}
  doc[root] = yield root

  if path.empty?
    ret[root] = doc[root] if root != 'id'
  else
    path.unshift root
    while !path.empty?
      aux = path.shift
      doc = doc[aux]
      if path.empty?
        ret[aux] = doc
      else
        ret = ret[aux] || ret[aux] = {}
      end
    end
  end
  ret_
end

