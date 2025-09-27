# ThreadArt Generator - AI Coding Instructions

## Project Architecture Overview

This is a **Taskmaster-managed** full-stack web application for converting digital images into string art patterns using mathematical optimization algorithms. The project uses a **task-driven development workflow** with comprehensive planning via PRDs and subtask breakdowns.

### Tech Stack & Key Components
- **Frontend**: Next.js 14+ (App Router) + Tailwind CSS + Zustand + React Query
- **Backend**: Fastify + TypeScript + Prisma ORM + PostgreSQL + Redis
- **Performance**: WebAssembly (Rust) for string art algorithms + Web Workers
- **Infrastructure**: Self-hosted Docker stack (PostgreSQL, Redis, Prometheus/Grafana)
- **Storage**: Cloudinary for image uploads and CDN
- **Authentication**: JWT or Keycloak for user management

## Development Workflow - Taskmaster Integration

### Core Workflow Pattern
This project follows a **Taskmaster-driven development process**. Before coding:

1. **Always check current tasks**: Use `mcp_task-master-a_get_tasks` to see active work
2. **Get next task**: Use `mcp_task-master-a_next_task` to identify what to work on
3. **Expand complex tasks**: Use `mcp_task-master-a_expand_task` before implementation
4. **Log progress iteratively**: Use `mcp_task-master-a_update_subtask` during development
5. **Mark completion**: Use `mcp_task-master-a_set_task_status` when done

### Key Files for Context
- **`.taskmaster/docs/PRD.txt`**: Complete product requirements and technical specifications
- **`.taskmaster/tasks/tasks.json`**: All project tasks with dependencies and subtasks
- **`.taskmaster/reports/task-complexity-report.json`**: Complexity analysis for task breakdown

## Project-Specific Patterns

### Infrastructure-First Approach
**CRITICAL**: Task #11 (Self-Hosted Infrastructure Setup) is the mandatory first step. All development requires:
- Docker Compose orchestration (PostgreSQL, Redis, Prometheus, Grafana, Nginx)
- Complete `.env` configuration with secure credentials
- Health checks and monitoring for all services
- Cloudinary integration for image storage

### Algorithm Architecture
The core string art generation uses a **multi-tier performance approach**:
1. **JavaScript implementation** (basic/fallback)
2. **Web Workers** for non-blocking computation 
3. **WebAssembly (Rust)** for maximum performance
4. **Rayon multi-threading** within WASM modules

### State Management Patterns
- **Zustand**: Client-side state (UI params, canvas state, user prefs)
- **React Query**: Server state and caching (projects, images, results) 
- **IndexedDB**: Local persistence for offline capability
- **Canvas 2D API**: Real-time rendering with OffscreenCanvas in workers

### API Design Conventions
- **Fastify** with TypeScript for type safety
- **Prisma ORM** for database operations with migrations
- **OpenAPI 3.0** documentation for all endpoints
- **JWT authentication** middleware for protected routes
- **BullMQ + Redis** for background job processing

## Implementation Guidelines

### Frontend Development
```typescript
// State management pattern with Zustand
interface AppState {
  currentProject: ImageProject | null;
  processingParams: ProcessingParameters;
  canvasState: CanvasState;
}

// Canvas rendering with workers
const useCanvasWorker = () => {
  const worker = useMemo(() => new Worker('/workers/canvas-worker.js'), []);
  // Handle thread visualization and animation
};
```

### Backend API Patterns
```typescript
// Fastify route with Prisma
app.post('/api/projects', {
  preHandler: authenticateJWT,
  schema: projectCreateSchema
}, async (request, reply) => {
  const project = await prisma.imageProject.create({
    data: request.body
  });
  return project;
});
```

### Algorithm Integration
- **JavaScript version**: Implement greedy line selection in `src/algorithm/js/`
- **WASM version**: Rust code in `packages/wasm/` compiled with wasm-pack
- **Performance fallbacks**: Graceful degradation for unsupported browsers

### Docker & Infrastructure
- **Self-hosted stack**: All services in `docker-compose.yml` 
- **Environment management**: Secure `.env` templates and health checks
- **Monitoring integration**: Prometheus metrics and Grafana dashboards
- **Backup automation**: PostgreSQL and Redis backup scripts

## Key Conventions

### Task Management Integration
- Reference task IDs in commit messages: `feat: implement image upload pipeline (Task #14.3)`
- Update subtasks during implementation with findings and progress
- Use complexity analysis before breaking down large features
- Follow dependency chains - never work on blocked tasks

### Error Handling
- Comprehensive error boundaries in React components
- Structured logging with correlation IDs
- Cloudinary upload failures with local storage fallback
- WASM compilation errors with JavaScript fallback

### Performance Considerations
- Image preprocessing limits: 10MB uploads, auto-resize to 256x256-512x512
- Canvas optimization: OffscreenCanvas for worker-based rendering
- Algorithm termination: Configurable iteration limits and convergence criteria
- Memory management: Cleanup for large image processing operations

### Testing Strategy
- **Unit tests**: Jest for algorithm functions and utilities
- **Integration tests**: API endpoints with test database
- **E2E tests**: Canvas rendering and full user workflows
- **Performance tests**: Algorithm benchmarking and memory profiling

## Development Environment Setup

### Required Tools
- Docker & Docker Compose for infrastructure
- Node.js 20+ for frontend/backend development  
- Rust toolchain for WASM compilation (`wasm-pack`)
- PostgreSQL client for database management

### Getting Started
1. **Infrastructure first**: Complete Task #11 setup (docker-compose, .env, health checks)
2. **Check Taskmaster tasks**: Get current status and next steps
3. **Follow task dependencies**: Never skip prerequisite tasks
4. **Iterative implementation**: Update subtasks frequently during development

This project emphasizes **infrastructure reliability**, **performance optimization**, and **systematic task-driven development**. Always consult the current Taskmaster context before beginning any implementation work.