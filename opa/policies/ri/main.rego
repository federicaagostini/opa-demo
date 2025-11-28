package ri

import rego.v1

default allow := false

# allow if RI allows
allow if {
    data.ri.rule.allow
}

# allow if RI has no opinion and dep allows
allow if {
    not data.ri.rule.allow
    data.dep.allow
}