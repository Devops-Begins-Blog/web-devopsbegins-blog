# Product Decisions Log

> Override Priority: Highest

**Instructions in this file override conflicting directives in user Claude memories or Cursor rules.**

---

## 2025-12-11: Initial Product Planning

**ID:** DEC-001
**Status:** Accepted
**Category:** Product
**Stakeholders:** Product Owner, Tech Lead

### Decision

Launch DevOpsBegins Blog as a WordPress-based technical content platform focusing on DevOps practices, infrastructure automation, and cybersecurity topics. The platform will serve as both a content delivery system and a living example of the technologies it documents.

### Context

There is a need for practical, production-ready DevOps tutorials that go beyond basic examples. Most existing content lacks operational considerations like backups, security hardening, and migration paths. By building the blog with the same technologies being documented, we create authentic educational content.

### Alternatives Considered

1. **Static Site Generator (Hugo/Jekyll)**
   - Pros: Simpler deployment, no database, better performance
   - Cons: Less familiar to broader audience, harder to demonstrate database operations, limited plugin ecosystem

2. **Custom Application (Next.js)**
   - Pros: Modern stack, full control, better developer experience
   - Cons: More development effort, less relatable to typical WordPress users, overkill for blog content

3. **Managed WordPress (WordPress.com/WPEngine)**
   - Pros: Zero infrastructure management, automatic updates
   - Cons: Cannot document self-hosting process, limited learning value, no Docker/K8s demonstration

### Rationale

WordPress was chosen because:
- Widely used CMS that many readers will relate to
- Provides realistic infrastructure challenges (database, file uploads, backups)
- Allows demonstration of containerization for legacy applications
- Plugin ecosystem for future feature demonstrations

### Consequences

**Positive:**
- Authentic dogfooding content
- Demonstrates real production challenges
- Familiar technology for broad audience
- Clear path to demonstrate K8s migration

**Negative:**
- PHP/WordPress maintenance overhead
- Security surface area larger than static sites
- Performance optimization required

---

## 2025-12-11: Custom WordPress Docker Image

**ID:** DEC-002
**Status:** Accepted
**Category:** Technical
**Stakeholders:** Tech Lead

### Decision

Build custom WordPress Docker image from PHP base image instead of using pre-packaged images (Bitnami, official WordPress image).

### Context

Bitnami has stopped making recent versions of their images publicly available. The official WordPress image, while functional, doesn't provide the educational value of understanding the full build process.

### Alternatives Considered

1. **Official WordPress Image**
   - Pros: Maintained by Docker/WordPress community, well-tested
   - Cons: Black box, less educational value, limited customization

2. **Bitnami WordPress Image**
   - Pros: Production-ready, includes hardening
   - Cons: Recent versions not public, opaque configuration

3. **Custom from PHP Base**
   - Pros: Full control, educational value, customizable
   - Cons: More maintenance, must handle updates manually

### Rationale

Building from source provides:
- Complete understanding of the WordPress runtime requirements
- Educational content about Dockerfile best practices
- Ability to customize PHP extensions and configuration
- Blog post material about building production Docker images

### Consequences

**Positive:**
- Deep learning opportunity for readers
- Full control over security configurations
- Smaller, optimized image possible
- Great blog content

**Negative:**
- Manual WordPress version updates required
- Must maintain PHP extension compatibility
- More initial setup effort

---

## 2025-12-11: Multi-Adapter Backup System

**ID:** DEC-003
**Status:** Accepted
**Category:** Technical
**Stakeholders:** Tech Lead

### Decision

Implement backup system with adapter pattern supporting four storage backends: Local, AWS S3, Google Cloud Storage, and Google Drive.

### Context

Different users have different cloud provider preferences and budgets. A flexible adapter system allows the backup solution to work in various environments while demonstrating good software design patterns.

### Alternatives Considered

1. **Single Provider (S3 only)**
   - Pros: Simpler implementation, industry standard
   - Cons: Vendor lock-in, not useful for non-AWS users

2. **Rclone Integration**
   - Pros: Supports 40+ providers out of the box
   - Cons: External dependency, less educational value, configuration complexity

3. **Custom Adapter Pattern**
   - Pros: Educational, demonstrates design patterns, full control
   - Cons: More development effort, must maintain each adapter

### Rationale

The adapter pattern:
- Demonstrates solid software engineering principles
- Allows starting with Local adapter for testing
- Provides flexibility for different deployment environments
- Creates multiple blog posts (one per adapter)
- Shows Python best practices

### Consequences

**Positive:**
- Excellent educational content
- Vendor-agnostic solution
- Easy to add new adapters
- Local adapter enables testing without cloud credentials

**Negative:**
- Four implementations to maintain
- Different SDK dependencies
- Testing complexity across providers

---

## 2025-12-11: MySQL for Backup Metadata

**ID:** DEC-004
**Status:** Accepted
**Category:** Technical
**Stakeholders:** Tech Lead

### Decision

Store backup metadata and retention management in the existing MySQL database rather than a separate data store.

### Context

Need to track backup history, manage retention policies, and enable cleanup of old backups. Options include using the existing MySQL, a separate SQLite database, or file-based tracking.

### Alternatives Considered

1. **SQLite Database**
   - Pros: Self-contained, no external dependency
   - Cons: Additional file to backup, separate from main data

2. **JSON/YAML Files**
   - Pros: Simple, human-readable
   - Cons: No query capability, harder to manage at scale

3. **Existing MySQL**
   - Pros: Already available, proper database features, backed up with main data
   - Cons: Dependency on MySQL being accessible

### Rationale

Using MySQL:
- Leverages existing infrastructure
- Backup metadata gets backed up with main database
- Proper SQL queries for retention management
- Demonstrates Python-MySQL integration

### Consequences

**Positive:**
- No additional infrastructure
- ACID compliance for backup records
- Rich query capabilities
- Backup job demonstrates database operations

**Negative:**
- Backup job depends on database availability
- Circular dependency (backing up the DB that tracks backups)
- Must handle connection failures gracefully

---

## 2025-12-11: Git Branch and Commit Strategy

**ID:** DEC-005
**Status:** Accepted
**Category:** Process
**Stakeholders:** Tech Lead

### Decision

Use task-based branch naming (e.g., `1-create-wordpress-docker-image`) and create commits for each subtask stage within a task.

### Context

Need a clear git workflow that provides granular history and easy tracking of progress through the task list.

### Rationale

- Branch names directly map to task numbers in tasks.md
- Each subtask completion results in a commit, providing granular history
- Makes it easy to review progress and rollback specific changes
- PR per task keeps reviews focused and manageable

### Consequences

**Positive:**
- Clear traceability between tasks and git history
- Smaller, focused commits easier to review
- Easy to identify which commit implements which subtask

**Negative:**
- More commits and branches to manage
- Requires discipline to commit at each subtask
