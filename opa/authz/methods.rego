package system.authz

import rego.v1

update_methods := [
	"PUT",
	"PATCH",
	"DELETE"
]

query_methods := [
	"GET",
	"HEAD",
	"POST"
]