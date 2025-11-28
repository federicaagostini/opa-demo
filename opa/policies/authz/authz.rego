package system.authz

import rego.v1

default allow := {
	"allowed": false,
	"reason": "Unauthorized resource access",
}

allow := {"allowed": true} if {
	_payload(input.identity).iss in data.authz.issuers
	input.method in _query_methods
}

allow := {"allowed": true} if {
	_payload(input.identity).iss in data.authz.issuers
	some group in _payload(input.identity)["wlcg.groups"]
	group in data.authz.groups
	input.method in _update_methods
}

allow := {"allowed": true} if {
	_payload(input.identity).iss in data.authz.issuers
	some group in _payload(input.identity).entitlements
	group in data.authz.groups
	input.method in _update_methods
}

allow := {"allowed": false, "reason": reason} if {
	not input.identity
	reason := "Missing bearer token"
}

