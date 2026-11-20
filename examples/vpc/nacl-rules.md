# Example NACL for a public web subnet

NACLs are **stateless**, so you must allow the return traffic yourself.
Return traffic uses **ephemeral ports** (1024-65535).

## Inbound

| Rule # | Type        | Protocol | Port range  | Source          | Allow/Deny |
|-------:|-------------|----------|-------------|-----------------|------------|
| 90     | All traffic | All      | All         | 203.0.113.0/24  | DENY  (known bad range) |
| 100    | HTTP        | TCP      | 80          | 0.0.0.0/0       | ALLOW |
| 110    | HTTPS       | TCP      | 443         | 0.0.0.0/0       | ALLOW |
| 120    | Custom TCP  | TCP      | 1024-65535  | 0.0.0.0/0       | ALLOW (replies to outbound calls) |
| *      | All traffic | All      | All         | 0.0.0.0/0       | DENY  |

## Outbound

| Rule # | Type        | Protocol | Port range  | Destination     | Allow/Deny |
|-------:|-------------|----------|-------------|-----------------|------------|
| 100    | HTTP        | TCP      | 80          | 0.0.0.0/0       | ALLOW (yum/dnf updates) |
| 110    | HTTPS       | TCP      | 443         | 0.0.0.0/0       | ALLOW |
| 120    | Custom TCP  | TCP      | 1024-65535  | 0.0.0.0/0       | ALLOW (replies to clients) |
| *      | All traffic | All      | All         | 0.0.0.0/0       | DENY  |

Rules are checked **lowest number first**; the first match wins. That is why
the DENY for the bad range is rule 90, before the ALLOW at 100.

## Matching Security Group (on the instance)

| Direction | Protocol | Port | Source/Destination | Notes |
|-----------|----------|------|--------------------|-------|
| Inbound   | TCP      | 80   | `sg-alb` (the ALB's security group) | Only the load balancer can reach the app |
| Outbound  | All      | All  | 0.0.0.0/0          | Default. Return traffic is automatic because SGs are stateful |
