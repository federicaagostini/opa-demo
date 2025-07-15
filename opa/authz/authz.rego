package system.authz

import rego.v1

default allow := {
	"allowed": false,
	"reason": "Unauthorized resource access",
}

allow := {"allowed": true} if {
	payload(input.identity).iss in data.authz.issuers
	input.method in query_methods
}

allow := {"allowed": true} if {
	some group in payload(input.identity).groups
	group in data.authz.groups
	input.method in update_methods
}

allow := {"allowed": false, "reason": reason} if {
	not input.identity
	reason := "Missing bearer token"
}

