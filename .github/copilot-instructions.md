# Threadart Schema Generator - AI Instructions

## Project Overview
A Next.js application for generating thread art schemas from images. The app converts visual patterns into instructions for creating physical thread art projects.

## Architecture & Tech Stack
- **Framework**: Next.js 15.5.4 with App Router (`/app` directory)
- **UI**: React 19.1.0 + Tailwind CSS with design system tokens
- **TypeScript**: Strict mode enabled with path aliases (`@/*` → `./`)
- **Styling**: Design system using CSS custom properties for theming

## Key Patterns & Conventions

### Styling System
- Uses HSL-based design tokens in `globals.css` with automatic dark mode
- Color system: `bg-background`, `text-foreground`, `border-border` etc.
- Gradients: `from-blue-50 to-indigo-100` with dark variants
- Component styling follows the pattern: `bg-white dark:bg-gray-800`

### File Structure
```
app/
├── globals.css      # Design system + Tailwind
├── layout.tsx       # Root layout with metadata
└── page.tsx         # Home page with feature overview
```

### Component Patterns
- Functional components with TypeScript
- Metadata defined in `layout.tsx` using Next.js convention
- Grid layouts: `grid grid-cols-1 md:grid-cols-2 gap-4`
- Status indicators: Green dot + text for system status

## Development Workflow
- **Task Management**: Uses Taskmaster for project planning (`.taskmaster/`)
- **Dev Server**: `npm run dev` (standard Next.js)
- **Build**: `npm run build && npm run start`
- **Linting**: `npm run lint` (ESLint with Next.js config)

## Domain-Specific Context
This is an image processing application for thread art generation:
- **Schema Generation**: Converting images to thread patterns
- **Pattern Analysis**: Analyzing visual elements for thread mapping  
- **Export Options**: Multiple output formats for physical creation
- **Image Processing**: Core functionality for visual-to-pattern conversion

## Critical Implementation Notes
- Path aliases configured: `@/*` maps to project root
- No external UI library - uses custom Tailwind components
- Design system ready for shadcn/ui integration (tokens match)
- Server external packages configured but empty (Next.js 15 compatibility)

## When Adding Features
1. Follow the established color/spacing tokens from `globals.css`
2. Use the grid + card pattern from the homepage for consistency
3. Implement TypeScript-first with proper type definitions
4. Add new routes under `/app` following App Router conventions
5. Consider image processing libraries will need Next.js config updates

## AI Development Guidelines
- Prioritize the thread art domain - schemas, patterns, image analysis
- Use existing design patterns (cards, grids, status indicators)
- Maintain TypeScript strict mode compliance
- Follow the established dark/light theme patterns
- Consider performance for image processing operations