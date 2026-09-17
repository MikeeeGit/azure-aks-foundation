# Dual-cluster upgrade and cutover

`aks01` and `aks02` are persistent infrastructure slots. “Blue” and “green” describe serving and candidate application roles, not Terraform resource names. Switching traffic must not rename either slot or move its state. Same-region dual clusters support upgrades; the separate `ukw/bcdr` state is a different regional recovery design requiring application/data replication.

## Prepare the candidate

1. Record current health, application revisions, backups, restore evidence and rollback deadline. Check database/schema compatibility with both app versions. Cluster creation does not replicate volumes, databases, queues, certificates or secrets.
2. Leave the serving slot's configuration unchanged. Add/update the candidate's independent Kubernetes version/pools. Check quota and capacity for two clusters plus surge. Keep unrelated outbound/DNS changes separate.
3. Review a saved infrastructure plan. It should create/update the candidate and expected identities/roles without replacing or deleting the serving slot. Apply after review.
4. Deploy reviewed application/GitOps configuration to the candidate, including its storage and secrets. Federate the candidate's distinct OIDC issuer for each workload subject. A dedicated application identity can explicitly trust both issuers; control-plane identities remain separate.
5. Verify Entra RBAC, nodes, image pulls, CSI, workload identity, network policy, DNS/egress and observability. Test application health/load and data recovery against the candidate alone.

## Establish ingress and gateway health

For the integrated single-application sample, deploy its internal LoadBalancer Service directly on each slot. A general multi-application platform can instead install a maintained ingress/Gateway API controller with its own internal Service. In either case use an unused node-subnet IP. `ingress_private_ip` is only the desired handoff. Verify the Service actually gets that IP, endpoints are ready and the application answers at the expected port, hostname, path and TLS SNI.

Pre-production examples use `10.81.0.20` and `10.81.4.20`. Application Gateway in the separate `appgateway` subnet can use these reachable ingress addresses. Match backend protocol/port, probe path, Host header, certificate trust and timeouts. Never use overlay pod CIDRs or the AKS private API endpoint as app backends. Validate health through the gateway's real network path before selecting a candidate backend.

This repository installs neither ingress nor traffic routing. A network/gateway plan does not prove a live endpoint. Keep a candidate-only hostname/test route during validation. Check controller support lifecycle rather than copying an archived chart/version.

## Cut over and observe

Approve the smallest independent gateway/listener/backend or DNS change selecting the candidate. Account for TTLs, connection draining, caches, sessions, WebSockets and long requests. Do not assume weighted canaries unless the selected traffic product supports them.

Monitor errors, latency, saturation, failed jobs, secret/identity failures and data integrity throughout the agreed observation period. Keep the old slot, ingress and federation operational for rollback. Record exact infrastructure, application and traffic revisions.

## Roll back or retire

Restore the previously verified traffic target for rollback and recheck health. Traffic reversal does not undo incompatible database migrations; retain a separately tested data recovery plan. Preserve evidence and useful data while investigating.

After the rollback window, prove the old slot receives no traffic or scheduled work. Migrate/retain its stateful data and backups, remove that slot from workload federation `clusters` sets, then remove only that key from the Terraform `clusters` map. Review its destruction plan and apply through protected delivery. The surviving slot's key/IDs stay stable. Retain shared network/DNS/backend resources until all consumers are gone.

Use the [readiness handoff](readiness.md) before candidate deployment and traffic selection. A historical deployment or successful mock plan does not prove current Azure or application health.
