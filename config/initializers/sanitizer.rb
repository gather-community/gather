# As of 12/11/17 the default tags are:
# strong em b i p code pre tt samp kbd var sub sup dfn cite big small address hr br div span
# h1 h2 h3 h4 h5 h6 ul ol li dl dt dd abbr acronym a img blockquote del ins
ActionView::Base.sanitized_allowed_tags += %w(table thead tbody tfoot tr th td)
