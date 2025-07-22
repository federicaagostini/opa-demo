# Open Policy Agent demo

This repo holds examples of policies writte in rego, evaluated with [Open Policy Agent](https://www.openpolicyagent.org/).

The exercize is to explore different OPA deployment models, as described in the [documentation](https://www.openpolicyagent.org/docs/external-data).

## Setup

### Credentials

The next examples which showcase read/write access to OPA APIs require you have a Bearer token issued by the [IAM DEV](https://iam-dev.cloud.cnaf.infn.it/). In order to update policies you also need to be part of the `admin` group:

* if you are still not a member, join [IAM DEV](https://iam-dev.cloud.cnaf.infn.it/) (click the bottom green button _Apply for an account_)
* request to join the `admin` group
* ask for a JWT using e.g. oidc-agent or [iam-test-client](https://iam-dev.cloud.cnaf.infn.it/iam-test-client)
* copy your token in the `BT` environment variable.

Alternatively, the `authz` key of the [data](./opa/data.yaml) file should be updated in order to authorize other issuers/groups.

### OPA bundle

Beside running the rego/data files, OPA allows to pull a bundle of policies/data from an external service. An OPA bundle is basically a tar.gz of the source code with a precise file hierarchy (for more documentation see [OPA bundles](https://www.openpolicyagent.org/docs/management-bundles)).

Here we use NGINX to expose the OPA bundle, but you need to create the bundle first.

Download the OPA binary (see [documentation](https://www.openpolicyagent.org/docs#1-download-opa)) with

```bash
curl -L -o opa-cli https://openpolicyagent.org/downloads/latest/opa_linux_amd64
chmod 755 ./opa-cli
```

and create the bundle

```bash
./opa-cli build -b opa -o dep.tar.gz
```

### Build & run

A [docker-compose](./docker-compose.yml) file available in the root directory contains several services:

* `trust`: docker image used to generate a test CA certificate on the fly and server/user certificates. When the container process finishes successfully, it populates the following volumes
  * `/etc/pki/tls/certs/ca-bundle.crt`: bundle with system certificates plus the test CA
  * `/trust-anchors`: folder that contains CA certificate/key
  * `/certs` server certificates
  * `/usercerts` user certificates
* `nginx`: it exposes the OPA bundle at https://nginx.test.example/bundles/dep.tar.gz
* `opa-pull`: OPA server available at https://opa-pull.test.example:8181, it pulls the bundle exposed by NGINX
* `opa-push`: OPA server available at https://opa-push.test.example:8182, it runs the source code (locally)
* `client`: client container used to query OPA.

Build the trustanchor with test certificates (it may be redone when certificates expire)

```bash
docker compose build --no-cache trust
```

Run the docker compose with

```bash
docker compose up -d
```

If you wish to copy the bundle served by NGINX and downloaded by OPA, type

```bash
docker compose cp opa-pull:/tmp/opa/bundles/dep .
```

In order to execute the next examples, enter in the client container

```bash
docker compose exec client bash
```

## Open Policy Agent

In this demo we are testing two OPA deployment models:

* `opa-pull` allows to read policies/data asynchronously from an external bundle, hosted by NGINX. The bundle may also be exposed by a GitHub package registry for instance. When reading from a bundle, OPA can act only in pull mode, meaning that the policies cannot be updated trough APIs. It is up to the external service to restrict who can update the bundle (in NGINX you can filter by IP, set a basic authentication, etc. - not implemented here), but in order to modify for instance some data you should then replace the entire bundle. This deployment model is useful when one requires a versioned control over the rego files/data. OPA is configured here to hold a copy of the policies at `/tmp/opa`
* `opa-push` runs the source code (rego files and data) locally and the policies may be updated from APIs. In this example we allow to update policies/data to users presenting a token issued by the [IAM DEV](https://iam-dev.cloud.cnaf.infn.it/) and containing the `/admin` group. In this OPA mode the policies are hold in memory, meaning that we need to deploy another service which queries OPA APIs and saves the policies if we want to persist them after an OPA restart. This deployment model may be useful when one wants to allow only selected users (e.g. admins) to update the policies for instance trough a dashboard.

In both deployment models read access of policies/data is granted to bearer token issued by the [IAM DEV](https://iam-dev.cloud.cnaf.infn.it/) (for more information, see below the _Authorization within OPA_ section).

### Policy API

The policy API allows to manage policy modules (rego files). The permitted operations are (for more information, see the [Policy API](https://www.openpolicyagent.org/docs/rest-api#policy-api) OPA documentation):
* `GET /v1/policies/` to list all the policy modules
* `GET /v1/policies/<id>` to get a single policy module
* `PUT /v1/policies/<id>` to create or entirely update a policy module
* `DELETE /v1/policies/<id>` to delete a policy module.

For instance, list the rego modules (allowed both to `opa-pull` and `opa-push` services) with:

```bash
$ curl https://opa-pull.test.example:8181/v1/policies -H "Authorization: Bearer $BT" -s | jq .result
[
    "id": "dep/opa/health/rules.rego",
    "raw": "package system.health\n\ndefault live := true\n\ndefault ready := false\n\nready if {\n\tinput.plugins_ready\n\tinput.plugin_state.bundle == \"OK\"\n}\n",
    "ast": {
      "package": {
        "path": [
          {
            "type": "var",
            "value": "data"
          },
...
```

A policy module is identified by its path, so to get a single policy:

```bash
$ curl https://opa-pull.test.example:8181/v1/policies/dep/opa/dep/policy.rego -H "Authorization: Bearer $BT" -s | jq .result
{
  "id": "dep/opa/dep/policy.rego",
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

### Data API

The data API allows to manage documents in OPA. An OPA document includes an object of the `data.jaml` file. The permitted operations are (for more information, see the [Data API](https://www.openpolicyagent.org/docs/rest-api#data-api) OPA documentation):
* `GET /v1/data/{path:.+}` to get the `data` object
* `PUT /v1/data/{path:.+}` to create or entirely update the `data` object
* `PATCH /v1/data/{path:.+}` to update the `data` object with input encoded as JSON Patch ([RFC 6902](https://datatracker.ietf.org/doc/html/rfc6902))
* `DELETE /v1/data/{path:.+}` to delete the `data` object.

Check the OPA data document (allowed both to `opa-pull` and `opa-push` services) with:

```bash
$ curl https://opa-pull.test.example:8181/v1/data -H "Authorization: Bearer $BT" -s | jq .result
{
  "authz": {
    "groups": [
      "/admin"
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
$ curl https://opa-pull.test.example:8181/v1/data/authz/groups -H "Authorization: Bearer $BT" -s | jq .result
[
  "admin"
]
```

Create or overwrite a document with the example methods (allowed by the `opa-push` service only) with

```bash
$ curl https://opa-push.test.example:8182/v1/data/authz/methods -H "Authorization: Bearer $BT" -d@/opa-examples/methods.json -XPUT
$ curl https://opa-push.test.example:8182/v1/data/authz/methods -H "Authorization: Bearer $BT" -s | jq .result
[
  "PUT",
  "PATCH",
  "DELETE"
]
```

Delete the example methods with

```bash
$ curl https://opa-push.test.example:8182/v1/data/authz/methods -H "Authorization: Bearer $BT" -XDELETE
$ curl https://opa-push.test.example:8182/v1/data/authz/methods -H "Authorization: Bearer $BT" -s
{}
```

If we want to add one element to the array identified by the `policies` key of the data.jaml file, we need to perform the JSON Patch operation as follows

```bash
$ curl https://opa-push.test.example:8182/v1/data/policies -XPATCH -H "Content-Type: application/json-patch+json" -H "Authorization: Bearer $BT" -d "$(jq -n --slurpfile val /opa-examples/policy.json '[{op: "add", path: "-", value: $val[0]}]')"
$ curl https://opa-push.test.example:8182/v1/data/policies -H "Authorization: Bearer $BT" -s | jq .result
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

When one tries to delete a data with OPA pulling from a bundle (`opa-pull` server) he gets an error such as

```bash
$ curl https://opa-pull.test.example:8181/v1/data/authz/groups -H "Authorization: Bearer $BT" -XDELETE
{
  "code": "invalid_parameter",
  "message": "all paths owned by bundle \"dep\""
}
```

### Query OPA

The data and query APIs allow to query OPA with some input in order to get a decision. The subtle difference among the two APIs lies in the OPA philosophy (see [OPA Document Model](https://www.openpolicyagent.org/docs/philosophy#the-opa-document-model)), but basically they both return the same allow/deny information. In practice, the permitted operations are:
* `POST /v1/data/{path:.+}` to get a `data` object which requires some input. The request body must be a JSON object wrapped by the `input` key
* `POST /` to get an OPA decision which requires some input. The request body must be a JSON object.

Query OPA through the data API with the input file as example (allowed both to `opa-pull` and `opa-push` services):

```bash
$ curl https://opa-pull.test.example:8181/v1/data/dep/allow -d@/opa-examples/input.json -H "Authorization: Bearer $BT" -s | jq .result
true
```

In case we want to get as response the entire `data` object, query OPA with:

```bash
$ curl https://opa-pull.test.example:8181/v1/data -d@/opa-examples/input.json -H "Authorization: Bea
rer $BT" -s | jq .result
{
  "authz": {
    "groups": [
      "/admin"
    ],
    "issuers": [
      "https://iam-dev.cloud.cnaf.infn.it/"
    ]
  },
  "dep": {
    "allow": true
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

Query OPA through the query API with the query file as example:

```bash
$ curl https://opa-pull.test.example:8181/ -d@/opa-examples/query.json -H "Authorization: Bearer $BT" -s | jq .
{
  "allow": true
}
```

### Authorization within OPA

For a secure OPA deployment, one would need to protect OPA APIs with some authorization. OPA allows you to configure an authorization based on TLS client certificates or bearer tokens. Once required, some rego file needs to be written in order to fine tune the desired authorization. In fact, When OPA receives a request, it executes a query against the document defined `data.system.authz.allow` (by default). The user's identity information will be provided in the `input.identity` document together with other useful keys (e.g. `method`, `path`, `headers`, etc.), which can be manipulated with rego. More information are available in the [documentation](www.openpolicyagent.org/docs/security).

In this repository, an `allow` rule is contained in the [system.authz](./opa/authz/authz.rego) package, providing
* read access to bearer tokens issued by the [IAM DEV](https://iam-dev.cloud.cnaf.infn.it/)
* write access to bearer token issued by the [IAM DEV](https://iam-dev.cloud.cnaf.infn.it/) and with `/admin` group.
The allowed token issuers and groups are listed in the [data.yaml](./opa/data.yaml) file.

In case you do not present a bearer token, you will get an error accessing all APIs like

```bash
$ curl https://opa-pull.test.example:8181/v1/data -s | jq .
{
  "code": "unauthorized",
  "message": "Missing bearer token"
}
```

In case your bearer token does not have sufficient privileges, you will get an error like

```bash
$ curl https://opa-push.test.example:8182/v1/data/authz/groups -H "Authorization: Bearer $BT" -XDELETE
{
  "code": "unauthorized",
  "message": "Unauthorized resource access"
}
```

### Health endpoint

OPA exposes an health endpoint, which executes a built-in policy query against the document defined `data.system.health` to verify that the server is operational. Optionally, it may be customize with some rego code to return the liveness/readiness state and other information. OPA will return an empty object with a 200 HTTP status code if the application is live/ready. For more information, see the [documentation](https://www.openpolicyagent.org/docs/rest-api#health-api). 

In this repository, a [`system.health`](./opa/health/rules.rego) package containig live/ready rule as been defined and may be queried with

```bash
$ curl https://opa-pull.test.example:8181/health/live -H "Authorization: Bearer $BT"
{}
```
