#!/bin/bash

# Hard-wraps ${v}TextIn every 40 chars into ${v}TextOut (declared here),
# one cell with newline-separated lines. A break that splits a word gets "-":
#   "Wipe down the baseboards in your room and clean your window"
#   -> "Wipe down the baseboards in your room an-\nd clean your window"
# Caller declares String ${v}TextIn before splicing this in, then reads ${v}TextOut.

v=${1}
# maps
. ${NSMAP}/bind ${v} TextIn TextOut

cat << EOF

    String ${v}Rest = (${!text_in} == null) ? "" : ${!text_in}.strip();
    String ${!text_out} = "";
    while (${v}Rest.length() > 40) {
        String ${v}Line = ${v}Rest.substring(0, 40);
        if (${v}Line.charAt(39) != ' ' && ${v}Rest.charAt(40) != ' ')
            ${v}Line = ${v}Line + "-";
        else
            ${v}Line = ${v}Line.stripTrailing();
        ${!text_out} = ${!text_out} + ${v}Line + "\n";
        ${v}Rest = ${v}Rest.substring(40).stripLeading();
    }
    ${!text_out} = ${!text_out} + ${v}Rest;

EOF
