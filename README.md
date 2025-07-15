# Open Policy Agent demo

Run the docker compose with

```bash
$ docker compose up -d
```

Query opa with an input file as example

```bash
$ curl http://localhost:8181/v1/data/dep/authz/allow -d@examples/input.json -s | jq .result
true
```