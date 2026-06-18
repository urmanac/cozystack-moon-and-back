---
title: "ADRs"
layout: page
---

# 📋 Architecture Decision Records (ADRs)

This directory contains Architecture Decision Records for the ARM64 Kubernetes project. ADRs document significant architectural decisions, their context, and consequences.

## 📑 ADR Index

| ADR | Title | Status | Date |
|-----|-------|--------|------|
| [ADR-001](ADR-001-ARM64-ARCHITECTURE.md) | ARM64 Architecture Choice | ✅ Accepted | 2025-11-16 |
| [ADR-002](ADR-002-TDG-METHODOLOGY.md) | Test-Driven Generation Methodology | ✅ Accepted | 2025-11-16 |
| [ADR-003](ADR-003-PATCH-GENERATION.md) | Patch Generation Best Practices | ✅ Accepted | 2025-11-16 |
| [ADR-004](ADR-004-ROLE-BASED-IMAGES.md) | Role-Based Talos Image Architecture | ✅ Accepted | 2025-11-18 |
| [ADR-005](ADR-005-SOVEREIGN-OS-FACTORY.md) | Sovereign OS Factory for Hardware Extension Integration | ✅ Accepted | 2026-06-18 |

## 🏗️ ADR Template

When creating new ADRs, use this structure:

```markdown
# ADR-XXX: [Title]

**Date:** YYYY-MM-DD  
**Status:** [Proposed/Accepted/Deprecated/Superseded]  
**Context:** [Brief context]  

## Summary
[Brief summary of the decision]

## Problem
[Problem statement and context]

## Decision
[The decision made and rationale]

## Alternatives Considered
[Other options that were evaluated]

## Consequences
[Impact of this decision]
```

## 🔗 Decision Flow

```
ADR-001 (ARM64 Choice) 
    ↓
ADR-002 (TDG Methodology)
    ↓  
ADR-003 (Patch Generation)
    ↓
ADR-005 (Sovereign OS Factory)
```

## 📚 Related Documentation

- **[TDG Success Story](../TDG-PLAN.md)** - Detailed implementation story
- **[Repository Overview](../REPO-OVERVIEW.md)** - High-level project structure
- **[Cost Analysis](../COST-ANALYSIS.md)** - Financial planning and validation

## 📝 Future ADR Topics

Potential decisions that may warrant ADRs:

- **ADR-004**: CozyStack Build System Integration (Makefile vs. Custom) (Superseded by ADR-005)
- **ADR-006**: Home Lab Hardware Selection Criteria
- **ADR-007**: Monitoring and Observability Stack
- **ADR-008**: Security Model for Hybrid Cloud-Lab Setup

---

📍 **Navigation**: [Home](../../README.md) | [Documentation Index](../README.md)
