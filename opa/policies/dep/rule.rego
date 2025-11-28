package dep.rule

import rego.v1

default allow := false

allow if {
	some policy in data.dep.policies
	input.action == policy.action
	input.resource.id == policy.target
	some constraint in policy.constraint
	input.token.acr == constraint.acr
	some entitlement in input.token.entitlements
	entitlement == policy.assignee
}
