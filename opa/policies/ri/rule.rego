package ri.rule

import rego.v1

allow if {
    some policy in data.ri.policies
	input.action == policy.action
	input.resource.id == policy.target
	some constraint in policy.constraint
	input.token.acr == constraint.acr
	some entitlement in input.token.entitlements
	entitlement == policy.assignee
}