# Registry Server Architecture Design

## Executive Summary

This document defines the architecture for the **allama Model Registry Server**, a centralized service for storing, sharing, and distributing LLM models. The registry server enables users to push and pull models, similar to ollama's registry, with aerospace-level security features.

**Technology Stack**: Go (Golang) for server implementation
**Protocol**: HTTP/HTTPS with REST API
**Storage**: Object storage (S3-compatible) + PostgreSQL database
**Authentication**: JWT tokens with OAuth2/OIDC support

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture Principles](#architecture-principles)
3. [System Architecture](#system-architecture)
4. [API Design](#api-design)
5. [Database Schema](#database-schema)
6. [Security Architecture](#security-architecture)
7. [Storage Architecture](#storage-architecture)
8. [Deployment Architecture](#deployment-architecture)
9. [Monitoring and Observability](#monitoring-and-observability)
10. [Implementation Roadmap](#implementation-roadmap)

---

## Overview

### Purpose

The registry server provides:
- **Model Storage**: Centralized storage for LLM models
- **Model Discovery**: Search and browse available models
- **Model Distribution**: Efficient download with resumable transfers
- **Model Versioning**: Tag-based version management
- **Access Control**: Authentication and authorization
- **Audit Trail**: Complete audit logging for compliance
- **Rate Limiting**: Protection against abuse

### Key Features

- RESTful API for model operations
- Resumable multipart uploads/downloads
- Model metadata indexing and search
- User authentication and authorization
- Model access controls (public/private)
- Model ratings and reviews
- Model statistics and analytics
- Web UI for model management

### Non-Goals

- Model hosting for inference (handled by llama-server)
- Model fine-tuning (handled by separate tools)
- Model conversion (handled by separate tools)
- Real-time collaboration

---

## Architecture Principles

### 1. Security First

All operations are authenticated and authorized. All data is encrypted at rest and in transit. Comprehensive audit logging for compliance.

### 2. Scalability

Horizontal scalability through stateless API servers. Distributed storage for model files. Database sharding for metadata.

### 3. Reliability

High availability through redundancy. Graceful degradation under load. Data replication across regions.

### 4. Performance

Efficient model downloads with CDN caching. Optimized database queries. Connection pooling.

### 5. Simplicity

Clear separation of concerns. Well-defined interfaces. Minimal dependencies.

---

## System Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Clients                              │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│  │ allama   │  │ Web UI   │  │ SDK      │  │ 3rd Party│  │
│  │ CLI      │  │          │  │          │  │ Tools     │  │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘  │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ HTTPS
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    Load Balancer / CDN                       │
│              (Nginx, Cloudflare, AWS ALB)                     │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                  API Gateway / Auth Layer                    │
│         (OAuth2/OIDC, JWT Validation, Rate Limiting)          │
└─────────────────────────────────────────────────────────────┘
                            │
            ┌───────────────┴───────────────┐
            ▼                               ▼
┌─────────────────────┐         ┌─────────────────────┐
│   API Server 1      │         │   API Server 2      │
│   (Go)              │         │   (Go)              │
│   - Model API       │         │   - Model API       │
│   - User API        │         │   - User API        │
│   - Search API      │         │   - Search API      │
└─────────────────────┘         └─────────────────────┘
            │                               │
            └───────────────┬───────────────┘
                            │
            ┌───────────────┴───────────────┐
            ▼                               ▼
┌─────────────────────┐         ┌─────────────────────┐
│   PostgreSQL       │         │   Object Storage     │
│   (Metadata)       │         │   (Model Files)      │
│   - Models         │         │   - S3/MinIO         │
│   - Users          │         │   - Multi-part       │
│   - Access Control │         │   - CDN Integration   │
└─────────────────────┘         └─────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    Monitoring & Logging                       │
│  (Prometheus, Grafana, ELK Stack, Audit Logs)              │
└─────────────────────────────────────────────────────────────┘
```

### Component Descriptions

#### 1. API Server (Go)

**Responsibilities**:
- Handle HTTP requests
- Validate authentication
- Enforce authorization
- Process business logic
- Coordinate with storage and database

**Key Packages**:
- `api`: HTTP handlers and middleware
- `auth`: Authentication and authorization
- `model`: Model management logic
- `storage`: Storage interface
- `database`: Database operations
- `audit`: Audit logging
- `cache`: Caching layer

#### 2. Database (PostgreSQL)

**Responsibilities**:
- Store model metadata
- Store user accounts
- Store access control policies
- Store audit logs
- Provide search indices

#### 3. Object Storage (S3/MinIO)

**Responsibilities**:
- Store model files
- Handle multipart uploads
- Provide CDN integration
- Manage lifecycle policies

#### 4. Authentication Layer

**Responsibilities**:
- OAuth2/OIDC provider integration
- JWT token validation
- Session management
- Rate limiting

---

## API Design

### Base URL

```
Production: https://registry.allama.ai
Development: http://localhost:8080
```

### Authentication

All API endpoints require authentication via JWT bearer token:

```
Authorization: Bearer <jwt_token>
```

### Endpoints

#### Model Operations

**List Models**
```
GET /api/v1/models
Query Parameters:
  - page: int (default: 1)
  - limit: int (default: 50)
  - search: string (optional)
  - tag: string (optional)
  - architecture: string (optional)
Response:
  {
    "models": [...],
    "total": 100,
    "page": 1,
    "limit": 50
  }
```

**Get Model Details**
```
GET /api/v1/models/{model_name}
Response:
  {
    "name": "llama3",
    "tag": "latest",
    "digest": "sha256:...",
    "size": 4294967296,
    "parameters": 7000000000,
    "quantization": "Q4_K_M",
    "architecture": "llama",
    "license": "MIT",
    "author": "meta",
    "created_at": "2026-04-30T00:00:00Z",
    "modified_at": "2026-04-30T00:00:00Z",
    "description": "...",
    "download_url": "https://...",
    "download_count": 1000
  }
```

**Push Model**
```
POST /api/v1/models
Request Body:
  {
    "name": "llama3",
    "tag": "latest",
    "file": <multipart file>,
    "metadata": {
      "parameters": 7000000000,
      "quantization": "Q4_K_M",
      "architecture": "llama",
      "license": "MIT",
      "description": "..."
    }
  }
Response:
  {
    "model_id": "uuid",
    "name": "llama3",
    "tag": "latest",
    "digest": "sha256:...",
    "status": "uploading"
  }
```

**Pull Model (Download)**
```
GET /api/v1/models/{model_name}/download
Response:
  - Redirect to pre-signed S3 URL
  - Supports Range requests for resumable downloads
```

**Delete Model**
```
DELETE /api/v1/models/{model_name}
Response:
  {
    "status": "deleted"
  }
```

**Copy Model**
```
POST /api/v1/models/{model_name}/copy
Request Body:
  {
    "destination": "llama3:custom"
  }
Response:
  {
    "status": "copied",
    "destination": "llama3:custom"
  }
```

#### User Operations

**Register User**
```
POST /api/v1/users/register
Request Body:
  {
    "username": "user",
    "email": "user@example.com",
    "password": "..."
  }
Response:
  {
    "user_id": "uuid",
    "username": "user",
    "email": "user@example.com"
  }
```

**Login**
```
POST /api/v1/users/login
Request Body:
  {
    "email": "user@example.com",
    "password": "..."
  }
Response:
  {
    "token": "jwt_token",
    "expires_in": 3600
  }
```

#### Search Operations

**Search Models**
```
GET /api/v1/search
Query Parameters:
  - q: string (required)
  - page: int (default: 1)
  - limit: int (default: 50)
Response:
  {
    "results": [...],
    "total": 50,
    "page": 1,
    "limit": 50
  }
```

#### Admin Operations

**Get Registry Statistics**
```
GET /api/v1/admin/stats
Response:
  {
    "total_models": 1000,
    "total_users": 100,
    "total_downloads": 10000,
    "storage_used": 1099511627776,
    "storage_available": 10995116277760
  }
```

---

## Database Schema

### Tables

#### models

```sql
CREATE TABLE models (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    tag VARCHAR(255) NOT NULL,
    digest VARCHAR(64) NOT NULL UNIQUE,
    size BIGINT NOT NULL,
    parameters BIGINT,
    quantization VARCHAR(50),
    architecture VARCHAR(100),
    license VARCHAR(100),
    author VARCHAR(255),
    description TEXT,
    family VARCHAR(100),
    format VARCHAR(50),
    backend VARCHAR(50),
    download_url TEXT,
    storage_path TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    modified_at TIMESTAMP NOT NULL DEFAULT NOW(),
    created_by UUID REFERENCES users(id),
    is_public BOOLEAN NOT NULL DEFAULT true,
    download_count BIGINT NOT NULL DEFAULT 0,
    rating_avg DECIMAL(3,2),
    rating_count INTEGER NOT NULL DEFAULT 0,
    UNIQUE(name, tag)
);

CREATE INDEX idx_models_name ON models(name);
CREATE INDEX idx_models_tag ON models(tag);
CREATE INDEX idx_models_digest ON models(digest);
CREATE INDEX idx_models_author ON models(author);
CREATE INDEX idx_models_architecture ON models(architecture);
CREATE INDEX idx_models_public ON models(is_public);
CREATE INDEX idx_models_created ON models(created_at DESC);
```

#### users

```sql
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(255) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    last_login_at TIMESTAMP,
    is_active BOOLEAN NOT NULL DEFAULT true,
    is_admin BOOLEAN NOT NULL DEFAULT false
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);
```

#### access_control

```sql
CREATE TABLE access_control (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    model_id UUID NOT NULL REFERENCES models(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    permission VARCHAR(50) NOT NULL, -- read, write, admin
    granted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    granted_by UUID REFERENCES users(id),
    UNIQUE(model_id, user_id)
);

CREATE INDEX idx_access_control_model ON access_control(model_id);
CREATE INDEX idx_access_control_user ON access_control(user_id);
```

#### audit_logs

```sql
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    action VARCHAR(100) NOT NULL,
    resource_type VARCHAR(100) NOT NULL,
    resource_id VARCHAR(255),
    ip_address INET,
    user_agent TEXT,
    status VARCHAR(50) NOT NULL,
    details JSONB,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_logs_user ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_action ON audit_logs(action);
CREATE INDEX idx_audit_logs_resource ON audit_logs(resource_type, resource_id);
CREATE INDEX idx_audit_logs_created ON audit_logs(created_at DESC);
```

#### model_ratings

```sql
CREATE TABLE model_ratings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    model_id UUID NOT NULL REFERENCES models(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    review TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE(model_id, user_id)
);

CREATE INDEX idx_ratings_model ON model_ratings(model_id);
CREATE INDEX idx_ratings_user ON model_ratings(user_id);
```

---

## Security Architecture

### Authentication Flow

```
1. User authenticates via OAuth2/OIDC provider
2. Provider issues JWT token
3. Client includes token in Authorization header
4. API Gateway validates token
5. Token claims (user_id, permissions) extracted
6. Request forwarded to API server with user context
```

### Authorization Model

**RBAC (Role-Based Access Control)**:
- **Anonymous**: Can list and download public models
- **User**: Can upload models, manage own models
- **Admin**: Can manage all models, users, and registry settings

**Resource-Based Access Control**:
- Models can be public or private
- Private models require explicit access grants
- Access grants can be read, write, or admin

### Security Features

1. **Transport Security**
   - TLS 1.3 for all connections
   - Certificate pinning
   - HSTS headers

2. **Data Encryption**
   - Encryption at rest (AES-256)
   - Encryption in transit (TLS)
   - Encrypted backups

3. **Input Validation**
   - Strict input validation
   - SQL injection prevention
   - XSS prevention

4. **Rate Limiting**
   - Per-user rate limits
   - Per-IP rate limits
   - Global rate limits

5. **Audit Logging**
   - All operations logged
   - Immutable log storage
   - Log retention policies

6. **Secrets Management**
   - HashiCorp Vault integration
   - Environment variable injection
   - Key rotation

---

## Storage Architecture

### Object Storage Strategy

**Storage Backend**: S3-compatible (AWS S3, MinIO, DigitalOcean Spaces)

**Model File Organization**:
```
s3://allama-registry/
├── models/
│   ├── {model_name}/{tag}/{model_file}
│   └── {model_name}/{tag}/metadata.json
├── uploads/
│   └── {upload_id}/{chunk_id}
└── cache/
    └── {cache_key}
```

**Multi-Part Upload**:
- Chunk size: 100MB
- Parallel uploads: 4 concurrent chunks
- Resume capability: Track uploaded chunks
- Cleanup: Abort incomplete uploads after 24h

**CDN Integration**:
- CloudFront CDN for global distribution
- Cache TTL: 24 hours
- Cache invalidation on model updates

### Database Strategy

**Connection Pooling**:
- Max connections: 100
- Idle connections: 10
- Connection lifetime: 1 hour

**Read Replicas**:
- Primary: Write operations
- Replicas: Read operations
- Lag monitoring

**Backup Strategy**:
- Daily full backups
- Hourly incremental backups
- Point-in-time recovery (7 days)

---

## Deployment Architecture

### Production Deployment

```
┌─────────────────────────────────────────────────────────────┐
│                     AWS / GCP / Azure                        │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │              VPC / Virtual Network                 │    │
│  │                                                     │    │
│  │  ┌──────────────┐  ┌──────────────┐              │    │
│  │  │ Public Subnet│  │Private Subnet│              │    │
│  │  │              │  │              │              │    │
│  │  │  ┌────────┐  │  │  ┌────────┐  │              │    │
│  │  │  │ LB     │  │  │  │API Srv │  │              │    │
│  │  │  │        │  │  │  │        │  │              │    │
│  │  │  └────────┘  │  │  └────────┘  │              │    │
│  │  │              │  │              │              │    │
│  │  │  ┌────────┐  │  │  ┌────────┐  │              │    │
│  │  │  │CDN     │  │  │  │PostgreSQL│ │              │    │
│  │  │  │        │  │  │  │          │  │              │    │
│  │  │  └────────┘  │  │  └────────┘  │              │    │
│  │  │              │  │              │              │    │
│  │  └──────────────┘  └──────────────┘              │    │
│  │                                                     │    │
│  └────────────────────────────────────────────────────┘    │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │              Object Storage (S3)                   │    │
│  └────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

### Kubernetes Deployment

**Deployment Manifests**:
- `api-server-deployment.yaml`: API server deployment
- `api-server-service.yaml`: API server service
- `postgres-deployment.yaml`: PostgreSQL deployment
- `postgres-service.yaml`: PostgreSQL service
- `ingress.yaml`: Ingress configuration

**Horizontal Pod Autoscaling**:
- Min replicas: 3
- Max replicas: 20
- Target CPU utilization: 70%
- Target memory utilization: 80%

---

## Monitoring and Observability

### Metrics

**Application Metrics** (Prometheus):
- Request rate by endpoint
- Request latency (p50, p95, p99)
- Error rate by endpoint
- Database connection pool metrics
- Storage operation metrics
- Cache hit/miss ratio

**System Metrics**:
- CPU utilization
- Memory utilization
- Disk I/O
- Network I/O
- Open file descriptors

### Logging

**Structured Logging** (JSON format):
```json
{
  "timestamp": "2026-04-30T00:00:00Z",
  "level": "info",
  "service": "registry-api",
  "user_id": "uuid",
  "action": "model_pull",
  "model_name": "llama3:latest",
  "ip_address": "192.168.1.1",
  "status": "success",
  "duration_ms": 150
}
```

**Log Aggregation**:
- ELK Stack (Elasticsearch, Logstash, Kibana)
- Log retention: 90 days
- Audit log retention: 365 days

### Tracing

**Distributed Tracing** (Jaeger/OpenTelemetry):
- Request tracing across services
- Database query tracing
- Storage operation tracing
- Performance bottleneck identification

### Alerting

**Alert Rules**:
- Error rate > 5% for 5 minutes
- P99 latency > 10s for 5 minutes
- Database connection pool exhaustion
- Storage operation failures
- Disk space > 80%

**Alert Channels**:
- PagerDuty for critical alerts
- Slack for warnings
- Email for informational

---

## Implementation Roadmap

### Phase 3.1: Core Server (4-6 weeks)

**Objective**: Implement basic registry server with model CRUD operations.

**Tasks**:
1. Set up Go project structure
2. Implement database schema migrations
3. Implement authentication layer (JWT)
4. Implement model API endpoints (list, get, upload, download)
5. Implement object storage integration (S3/MinIO)
6. Implement basic audit logging
7. Write unit tests
8. Write integration tests

**Deliverables**:
- Working registry server
- API documentation (OpenAPI/Swagger)
- Test suite
- Deployment guide

### Phase 3.2: Advanced Features (4-6 weeks)

**Objective**: Add advanced features for production readiness.

**Tasks**:
1. Implement multi-part upload
2. Implement search API with full-text search
3. Implement user management API
4. Implement access control (RBAC)
5. Implement model ratings and reviews
6. Implement CDN integration
7. Implement rate limiting
8. Implement monitoring and logging

**Deliverables**:
- Enhanced registry server
- Monitoring dashboard
- Performance benchmarks

### Phase 3.3: Web UI (4-6 weeks)

**Objective**: Build web UI for model management.

**Tasks**:
1. Design UI/UX
2. Implement model browser
3. Implement model upload interface
4. Implement user dashboard
5. Implement model details page
6. Implement search interface
7. Implement admin panel
8. Write UI tests

**Deliverables**:
- Web UI application
- UI documentation
- User guide

### Phase 3.4: Production Hardening (2-4 weeks)

**Objective**: Prepare for production deployment.

**Tasks**:
1. Security audit
2. Performance optimization
3. Load testing
4. Disaster recovery planning
5. Documentation completion
6. Compliance review
7. Production deployment
8. Post-deployment monitoring

**Deliverables**:
- Production-ready registry server
- Security audit report
- Performance report
- Deployment documentation

---

## Technology Stack Summary

### Backend

- **Language**: Go 1.21+
- **Framework**: Chi (router), GORM (ORM)
- **Database**: PostgreSQL 15+
- **Storage**: AWS S3 / MinIO
- **Cache**: Redis 7+
- **Message Queue**: NATS / RabbitMQ (optional)

### Frontend

- **Framework**: React 18+ / Vue 3+
- **UI Library**: Tailwind CSS / shadcn/ui
- **State Management**: Redux / Pinia
- **Build Tool**: Vite

### DevOps

- **Container**: Docker
- **Orchestration**: Kubernetes
- **CI/CD**: GitHub Actions / GitLab CI
- **Infrastructure**: Terraform / Pulumi
- **Monitoring**: Prometheus, Grafana, Jaeger
- **Logging**: ELK Stack

### Security

- **Authentication**: OAuth2/OIDC
- **Secrets**: HashiCorp Vault
- **Encryption**: OpenSSL / AWS KMS
- **WAF**: Cloudflare WAF / AWS WAF

---

## References

1. [Ollama Registry](https://github.com/ollama/ollama)
2. [Docker Hub API](https://docs.docker.com/registry/spec/api/)
3. [Hugging Face Hub API](https://huggingface.co/docs/hub/api)
4. [OWASP API Security](https://owasp.org/www-project-api-security/)
5. [NIST SP 800-53](https://csrc.nist.gov/publications/detail/sp/800-53/rev-5/final)

---

## Version History

- **v1.0.0** (2026-04-30): Initial architecture design
