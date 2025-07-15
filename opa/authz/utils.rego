package system.authz

import rego.v1

payload(token) := p if {
 	[_, p, _] := io.jwt.decode(token) 
}