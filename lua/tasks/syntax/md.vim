hi def link TaskLink Underlined
" hi def link TaskMeta Comment
syntax region TaskUUID matchgroup=Comment start=/@{/ end=/}/
hi def link @markup.link.label.markdown_inline NONE
syntax match TaskMeta '[a-z]\+:: [ a-zA-Z_0-9:-]\+'
syntax match TaskLink '[[[a-zA-Z/_.|-]\+]]'
syntax match TaskTag '#[a-zA-Z]\+[a-zA-Z0-9_+-]\+'
