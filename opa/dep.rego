package dep.authz

import rego.v1

default allow := false

allow if {
	input.action == data.action
	input.resource.id == data.target
	some constraint in data.constraint
	input.token.acr == constraint.acr
	some entitlement in input.token.entitlements
	entitlement == data.assignee
}
