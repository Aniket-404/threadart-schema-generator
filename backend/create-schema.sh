#!/bin/bash
echo "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";" | psql -U threadart_user -d threadart_db

# Run the migration SQL directly
psql -U threadart_user -d threadart_db << 'EOF'
-- CreateEnum
CREATE TYPE "ProjectStatus" AS ENUM ('CREATED', 'PROCESSING', 'COMPLETED', 'FAILED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "AlgorithmType" AS ENUM ('GREEDY', 'GENETIC', 'SIMULATED_ANNEALING', 'HYBRID');

-- CreateTable
CREATE TABLE "users" (
    "id" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "password" TEXT NOT NULL,
    "name" TEXT,
    "avatar" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "user_sessions" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "token" TEXT NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "user_sessions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "image_projects" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "status" "ProjectStatus" NOT NULL DEFAULT 'CREATED',
    "originalImage" TEXT NOT NULL,
    "imageWidth" INTEGER NOT NULL,
    "imageHeight" INTEGER NOT NULL,
    "imageFormat" TEXT NOT NULL,
    "imageSize" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "processedAt" TIMESTAMP(3),
    "userId" TEXT NOT NULL,

    CONSTRAINT "image_projects_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "processing_parameters" (
    "id" TEXT NOT NULL,
    "projectId" TEXT NOT NULL,
    "canvasWidth" INTEGER NOT NULL DEFAULT 500,
    "canvasHeight" INTEGER NOT NULL DEFAULT 500,
    "numPins" INTEGER NOT NULL DEFAULT 256,
    "maxLines" INTEGER NOT NULL DEFAULT 4000,
    "lineOpacity" DOUBLE PRECISION NOT NULL DEFAULT 0.8,
    "algorithm" "AlgorithmType" NOT NULL DEFAULT 'GREEDY',
    "iterations" INTEGER NOT NULL DEFAULT 1000,
    "convergenceThreshold" DOUBLE PRECISION NOT NULL DEFAULT 0.001,
    "backgroundColor" TEXT NOT NULL DEFAULT '#FFFFFF',
    "threadColor" TEXT NOT NULL DEFAULT '#000000',
    "useWebAssembly" BOOLEAN NOT NULL DEFAULT true,
    "useWebWorkers" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "processing_parameters_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "string_art_results" (
    "id" TEXT NOT NULL,
    "projectId" TEXT NOT NULL,
    "threadPath" JSONB NOT NULL,
    "previewImage" TEXT NOT NULL,
    "totalLines" INTEGER NOT NULL,
    "processingTime" INTEGER NOT NULL,
    "algorithmUsed" "AlgorithmType" NOT NULL,
    "similarity" DOUBLE PRECISION,
    "contrast" DOUBLE PRECISION,
    "sharpness" DOUBLE PRECISION,
    "generatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "string_art_results_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");

-- CreateIndex
CREATE UNIQUE INDEX "user_sessions_token_key" ON "user_sessions"("token");

-- CreateIndex
CREATE UNIQUE INDEX "processing_parameters_projectId_key" ON "processing_parameters"("projectId");

-- CreateIndex
CREATE UNIQUE INDEX "string_art_results_projectId_key" ON "string_art_results"("projectId");

-- AddForeignKey
ALTER TABLE "user_sessions" ADD CONSTRAINT "user_sessions_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "image_projects" ADD CONSTRAINT "image_projects_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "processing_parameters" ADD CONSTRAINT "processing_parameters_projectId_fkey" FOREIGN KEY ("projectId") REFERENCES "image_projects"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "string_art_results" ADD CONSTRAINT "string_art_results_projectId_fkey" FOREIGN KEY ("projectId") REFERENCES "image_projects"("id") ON DELETE CASCADE ON UPDATE CASCADE;

EOF

echo "Database schema created successfully!"