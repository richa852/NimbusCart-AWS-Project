# NimbusCart — Report

## Stack choice

- **API:** Flask (Python), chosen for minimal boilerplate around three routes.
- **Database:** PostgreSQL, connected via `psycopg2`.
- **Frontend:** static `index.html` + vanilla JS, no build step, served by nginx.

## Task A — Manual local run (verified)

The API and frontend were run locally against a real PostgreSQL instance before any AWS work,
per the assignment's checklist. All checklist items were exercised directly rather than assumed:

- [x] `GET /health` returns `200` with the API up but before any table exists.
- [x] `GET /items` returns `[]` on a fresh database, and the table appears via `psql`.
- [x] `POST /items` with a JSON body inserts a row and returns it, `id` included.
- [x] The frontend renders the table on load and the "Add product" form works against the local API.
- [x] The frontend shows a visible error state when the API is unreachable.

See `evidence/01_local_api_test.png` for the terminal session (health check → empty catalog →
schema confirmed via `psql \dt` → two POSTs → final GET). See `evidence/02_frontend_loaded.png`,
`evidence/03_frontend_after_add.png`, and `evidence/04_frontend_error_state.png` for the three
required frontend states, captured from the page actually running against the live API (and,
for the error state, with the API process stopped).

## Task A — Manual peering experiment

This part requires a real AWS account (build two throwaway VPCs, peer them, break the return
route on purpose, and screenshot the failure). That step wasn't run as part of this handoff —
no AWS credentials were available in the environment used to prepare this project — so treat the
two answers below as the conceptual explanation to verify against your own console output, not
as a substitute for actually doing it.

**1. What happens if you forget the return route in the data VPC's route table?**

The connection breaks asymmetrically. The App VPC's route table has a route to the Data VPC's
CIDR via the peering connection, so App→RDS packets arrive fine. But the Data VPC's route table
has no matching route back to the App VPC's CIDR, so RDS's replies have nowhere to go — they're
dropped locally in the Data VPC. From the client side this looks like a connection that hangs and
times out rather than one that's actively refused, because the SYN arrives but the SYN-ACK never
finds its way back. Fix: add a route in the Data VPC's table for the App VPC's CIDR block,
pointing at the peering connection — both sides need a route, not just the initiator.

**2. Why does the DB subnet need no NAT Gateway at all, even though it must be reachable from another VPC?**

NAT Gateways solve a different problem: they let resources in a private subnet *initiate*
outbound connections to destinations outside their own VPC (e.g., a private EC2 instance pulling
a package from the internet). RDS here never initiates anything outbound — it only accepts
inbound connections from the App tier. "Reachable from" (inbound, solved by peering + routing +
security groups) and "can initiate connections to" (outbound, solved by NAT) are separate
concerns, and this subnet only needs the first one.

## Task C — Conceptual questions

**1. Why must the DB subnet group span multiple AZs even for a single-AZ RDS instance? What breaks if it doesn't?**

AWS requires an RDS DB subnet group to cover at least two AZs before it will let you create an
instance in it at all, single-AZ or not — the requirement is enforced at subnet-group creation
time, not instance creation time. Practically, this exists so that flipping `multi_az = true`
later, or having AWS fail an instance over during an AZ-level event, always has a valid second
location to land in. Give the subnet group only one AZ and `aws_db_instance` creation fails
outright with a subnet-group validation error, even though the instance you're requesting is
single-AZ.

**2. Contrast VPC Peering with a Transit Gateway for this use case. At what point would you recommend switching?**

Peering is a direct, point-to-point connection between exactly two VPCs — no extra resource to
provision, no per-hour cost, and for two VPCs it's strictly simpler to reason about than a hub.
It doesn't scale gracefully, though: N VPCs that all need to talk to each other require
essentially N(N-1)/2 individual peering connections, each with its own routes to maintain, and
peering connections aren't transitive (if A peers with B and B peers with C, A still can't reach
C through B). A Transit Gateway trades a small per-attachment cost and an extra hop for a single
hub that every VPC attaches to once, with routing centralized in one place. I'd switch once a
third VPC needs to talk to the existing two — that's the point where the peering mesh starts
requiring quadratic effort to maintain versus linear effort for a TGW attachment.

**3. Your app tier has no public IP and no NAT route of its own beyond the shared NAT Gateway — walk through exactly how the app tier's user_data still manages to authenticate to ECR and pull the image.**

Three things combine to make this work without a public IP on the instance:

1. **IAM, not network identity.** The App EC2 instance has an instance profile
   (`aws_iam_instance_profile.app_profile`) attached, granting
   `AmazonEC2ContainerRegistryReadOnly`. The instance can call `aws ecr get-login-password`
   locally and get back a valid, short-lived token — this happens over the instance metadata
   service, not the public internet, so it doesn't need a public IP or NAT for the credential
   step itself.
2. **The actual ECR API call needs egress**, though — `docker login` and the subsequent
   `docker pull` are HTTPS calls to `*.dkr.ecr.<region>.amazonaws.com`. Since the App subnet's
   route table sends `0.0.0.0/0` to the shared NAT Gateway sitting in the public subnet, those
   outbound HTTPS calls go: App instance → NAT Gateway (using the NAT's Elastic IP as source) →
   Internet Gateway → ECR. The instance itself never has a public IP; the NAT Gateway is
   effectively borrowing one on its behalf for outbound-only traffic.
3. **`user_data` sequences it on first boot** — installs Docker and the AWS CLI, runs the ECR
   login, then `docker pull` and `docker run`, all before the instance is considered "ready."

**4. Security groups are stateful, NACLs are not. Give one concrete scenario in this architecture where that distinction would bite you if you got NACL rules wrong.**

Say a NACL on the data subnet allows inbound TCP/5432 from the App subnet's CIDR (matching the
security group), but someone locks down the NACL's outbound rules to "just the ports we
explicitly use" and forgets ephemeral ports. The App tier opens a connection from some
high-numbered ephemeral source port (say 51342) to RDS's 5432. The inbound leg is fine — it
matches the 5432 rule. But RDS's *reply* is a new packet, from 5432 back to port 51342, and
that's evaluated against the NACL's *outbound* rules independently, because NACLs don't track
connection state the way security groups do. If the outbound rule set doesn't include the
ephemeral range (roughly 1024–65535), that reply gets silently dropped at the data subnet's
boundary. Every Postgres connection would hang and eventually time out, even though the security
group — which *is* stateful and would have allowed the return traffic automatically — looks
completely correctly configured. This is exactly the kind of failure that's confusing to debug
because the obvious suspect (the SG) is innocent.

**5. `local-exec` provisioners are widely discouraged in production Terraform. Explain why, specifically in terms of what Terraform can and can't track — then justify why it's acceptable for the image-build step in this assignment.**

Terraform's whole model is built around comparing declared resource attributes against real
infrastructure state and computing a diff. A `local-exec` provisioner is an opaque shell command
— Terraform records that it *ran*, but has no visibility into what it *did*: which files it
touched, which external systems it called, what state it left behind. If that command mutates
something outside of a tracked resource attribute, Terraform has no way to detect drift on it
later, and no way to "destroy" or "repair" whatever it changed short of re-running the same
command and hoping it's idempotent. It's tolerated here because the blast radius is narrow and
well-understood: the command only builds a Docker image and pushes it to a tag in an ECR
repository that *is* a first-class Terraform resource (`aws_ecr_repository.api_repo`). The
side effect (a new image in the registry) isn't something Terraform needs to reconcile on
subsequent plans — it's a one-way deployment action, retriggered deliberately via the
`filesha256` trigger when the source changes, not something with ongoing state that drifts.

**6. Why does `backend.tf` deliberately not live in the same state it configures? What bootstrapping problem is being avoided?**

A remote backend's whole job is to tell Terraform *where* to read and write its state file — but
to do that, the S3 bucket and DynamoDB lock table it points to have to already exist. If creating
that bucket and table were resources inside the same configuration that uses them as its backend,
you'd hit a circular dependency: Terraform would need to already have remote state (to know
whether the bucket exists) before it could create the bucket that remote state depends on. The
standard fix is to bootstrap the bucket and lock table once — by hand, with a tiny separate
one-off Terraform config using local state, or via `aws` CLI — and only point `backend.tf` at
them afterward. `backend.tf` in this project assumes that bootstrap has already happened;
it configures the backend, it doesn't create it.

## Known limitations of this handoff

- Terraform code (`terraform/`) was written to match the required architecture and outputs but
  was **not run against a real AWS account** in the environment used to prepare this project —
  there was no AWS access available. Run `terraform validate` and `terraform plan` yourself
  before applying, and expect to fill in `var.key_pair_name` and `var.ssh_private_key_path`
  for your own account.
- The Docker build/push step (`docker build` in `main.tf`'s `local-exec`, and the Dockerfile
  itself) was likewise not run through an actual `docker build` in this environment — no Docker
  daemon was available — so double-check the image builds cleanly on your machine before relying
  on the Terraform `local-exec` step.
- Everything under **Task A — Manual local run** above *was* actually executed: real Flask
  process, real PostgreSQL database, real HTTP requests, real browser rendering the real
  frontend. Those screenshots are genuine captures, not mockups.
