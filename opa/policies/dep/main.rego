package dep

import rego.v1

default allow := false

allow if data.dep.rule.allow