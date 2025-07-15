# Open Policy Agent demo

Run the docker compose with

```bash
$ docker compose up -d
```

## Setup

The next examples require you have a Bearer token issued by the [IAM DEV](https://iam-dev.cloud.cnaf.infn.it/). In order to update policies you also need to be part of the `admin` group

* if you are still not a member, join [IAM DEV](https://iam-dev.cloud.cnaf.infn.it/) (click the bottom green button _Apply for an account_)
* request to join the `admin` group
* ask for a JWT using e.g. oidc-agent or [iam-test-client](https://iam-dev.cloud.cnaf.infn.it/iam-test-client)
* copy your token in the `BT` environment variable.

## Query OPA

To read OPA policies, data and query the service you will need a bearer token issued by trusted authorization servers (here [IAM DEV](https://iam-dev.cloud.cnaf.infn.it/)). 

Query OPA with the input file as example:

```bash
$ curl http://localhost:8181/v1/data/dep/allow -d@examples/input.json -H "Authorization: Bearer $BT" -s | jq .result
true
```

### OPA data

Check the OPA data document with

```bash
$ curl http://localhost:8181/v1/data -H "Authorization: Bearer $BT" -s | jq .result
{
  "authz": {
    "groups": [
      "admin"
    ],
    "issuers": [
      "https://iam-dev.cloud.cnaf.infn.it/"
    ]
  },
  "default_decision": "dep",
  "dep": {
    "allow": false
  },
  "policies": [
    {
      "action": "read",
      "assignee": "urn:example:aai.example.org:group:project-x:role=member",
      "constraint": [
        {
          "acr": "https://refeds.org/profile/mfa"
        }
      ],
      "target": "https://data.deps.eu/dataset/abc123"
    }
  ]
}
```

The path separator is used to access values inside object and array documents, e.g.

```bash
$ curl http://localhost:8181/v1/data/authz/groups -H "Authorization: Bearer $BT" -s | jq .result
[
  "admin"
]
```

### OPA rego

Check the rego modules with

```bash
$ curl http://localhost:8181/v1/policies -H "Authorization: Bearer $BT" -s | jq .result
[
    {
        "id": "etc/opa/dep/policy.rego",
        "raw": "package dep\n\nimport rego.v1\n\ndefault allow := false\n\nallow if {\n\tsome policy in data.policies\n\tinput.action == policy.action\n\tinput.resource.id == policy.target\n\tsome constraint in policy.constraint\n\tinput.token.acr == constraint.acr\n\tsome entitlement in input.token.entitlements\n\tentitlement == policy.assignee\n}\n",
        "ast": {
          "package": {
            "path": [
              {
                "type": "var",
                "value": "data"
              },
...
```

A policy module is identified by its path, so to query a single module:

```bash
$ curl http://localhost:8181/v1/policies/etc/opa/dep/policy.rego -H "Authorization: Bearer $BT" -s | jq .result
{
  "id": "etc/opa/dep/policy.rego",
  "raw": "package dep\n\nimport rego.v1\n\ndefault allow := false\n\nallow if {\n\tsome policy in data.policies\n\tinput.action == policy.action\n\tinput.resource.id == policy.target\n\tsome constraint in policy.constraint\n\tinput.token.acr == constraint.acr\n\tsome entitlement in input.token.entitlements\n\tentitlement == policy.assignee\n}\n",
  "ast": {
    "package": {
      "path": [
        {
          "type": "var",
          "value": "data"
        },
...
```

This endpoint allows a PUT operation to totally replace the module, or create a new one if it does not exists. Anyway, we prefer to leave admins to only update the data document.

## Update data

In order to update the data document you need an IAM token with proper `admin` group.

Create or overwrite a document with the example methods with

```
$ curl http://localhost:8181/v1/data/authz/methods -H "Authorization: Bearer $BT" -d@examples/methods.json -XPUT
$ curl http://localhost:8181/v1/data/authz -H "Authorization: Bearer $BT" -s | jq .result
{
  "groups": [
    "admin"
  ],
  "issuers": [
    "https://iam-dev.cloud.cnaf.infn.it/"
  ],
  "methods": [
    "PUT",
    "PATCH",
    "DELETE"
  ]
}
```

Delete the example methods with

```bash
$ curl http://localhost:8181/v1/data/authz/methods -H "Authorization: Bearer $BT" -XDELETE
$ curl http://localhost:8181/v1/data/authz -H "Authorization: Bearer $BT" -s | jq .result
{
  "groups": [
    "admin"
  ],
  "issuers": [
    "https://iam-dev.cloud.cnaf.infn.it/"
  ]
}
```

Patch the document with the example policy

```bash
$ curl http://localhost:8181/v1/data/policies -XPATCH -H "Content-Type: application/json-patch+json" -H "Authorization: B
earer $BT" -d '[{"op": "add", "path": "-", "value": {
    "action": "write",
    "assignee": "urn:example:aai.example.org:group:project-x:role=admin",
    "constraint": [
      {
        "acr": "https://refeds.org/profile/mfa"
      }
    ],
    "target": "https://data.deps.eu/dataset/abc123"
  }
}]'
$ curl http://localhost:8181/v1/data/policies -H "Authorization: Bearer $BT" -s | jq .result
[
  {
    "action": "read",
    "assignee": "urn:example:aai.example.org:group:project-x:role=member",
    "constraint": [
      {
        "acr": "https://refeds.org/profile/mfa"
      }
    ],
    "target": "https://data.deps.eu/dataset/abc123"
  },
  {
    "action": "write",
    "assignee": "urn:example:aai.example.org:group:project-x:role=admin",
    "constraint": [
      {
        "acr": "https://refeds.org/profile/mfa"
      }
    ],
    "target": "https://data.deps.eu/dataset/abc123"
  }
]
```