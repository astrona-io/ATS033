---
draft: true
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Minimize host OS footprint (reduce attack surface)

A worker hosts unused network services and development tools. Removing unnecessary components reduces exposed behavior, but removing a runtime dependency can also break legitimate workloads.

The explanations identify the responsible components, compare intended and observed state, and work through the decisions needed to preserve the requirement. Read the worked examples as reasoning about a proposed system; no environment is started by this section.

Read the module goals, teaching and closing summary in order. YAML checks are indexed separately and appear after designated summaries. Larger domains include an intermediate checkpoint before the final review.

## Learning Outcomes

- Inventory services, packages and privileged interfaces by required function.
- Explain why host compromise affects container isolation.
- Evaluate persistent service configuration and patch ownership.
- Preserve operational dependencies while removing unnecessary exposure.

## Module

**Reduce The Host Operating-System Attack Surface** has a landing page, four deep-dive parts, a summary and a knowledge check:

- Inventory Services And Listeners
- Stop, Disable And Mask Services
- Remove Packages And Keep The Node Working
- Privileged Host Interfaces
- Summary
- Knowledge check (10 questions)
