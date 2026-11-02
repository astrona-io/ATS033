---
draft: true
exam_objectives:
- Minimize external access to the network
---
# Minimize external access to the network

A management service listens on all interfaces even though administrators use one protected network. Its exposure exceeds its operating requirement regardless of whether application Services are restricted.

The explanations identify the responsible components, compare intended and observed state, and work through the decisions needed to preserve the requirement. Read the worked examples as reasoning about a proposed system; no environment is started by this section.

Read the module goals, teaching and closing summary in order. YAML checks are indexed separately and appear after designated summaries. Larger domains include an intermediate checkpoint before the final review.

## Learning Outcomes

- Map host listeners and required communication peers.
- Distinguish bind addresses, filtering and endpoint authorization.
- Evaluate ingress and egress rules without breaking dependencies.
- Account for persistence, address families and alternate traffic paths.

## Module

**Minimize External Access To The Network** has a landing page, four deep-dive parts, a summary and a knowledge check:

- Listeners And Bind Addresses
- Host Firewalls With iptables And ufw
- NetworkPolicy For Pod Traffic
- NodePorts, Control-Plane Ports And API Access
- Summary
- Knowledge check (10 questions)
