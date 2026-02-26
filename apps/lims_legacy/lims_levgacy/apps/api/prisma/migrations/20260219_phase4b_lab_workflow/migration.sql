-- Phase 4B: LAB catalog, ordered tests, structured results, verification workflow

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'LabOrderItemStatus') THEN
    CREATE TYPE "LabOrderItemStatus" AS ENUM ('ORDERED', 'RESULTS_ENTERED', 'VERIFIED');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'LabResultFlag') THEN
    CREATE TYPE "LabResultFlag" AS ENUM ('LOW', 'HIGH', 'NORMAL', 'ABNORMAL', 'UNKNOWN');
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS "LabTestDefinition" (
  "id" TEXT NOT NULL,
  "tenantId" TEXT NOT NULL,
  "code" TEXT NOT NULL,
  "name" TEXT NOT NULL,
  "department" TEXT NOT NULL,
  "active" BOOLEAN NOT NULL DEFAULT true,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "LabTestDefinition_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "LabTestParameter" (
  "id" TEXT NOT NULL,
  "tenantId" TEXT NOT NULL,
  "testId" TEXT NOT NULL,
  "name" TEXT NOT NULL,
  "unit" TEXT,
  "refLow" DOUBLE PRECISION,
  "refHigh" DOUBLE PRECISION,
  "refText" TEXT,
  "displayOrder" INTEGER NOT NULL DEFAULT 0,
  "active" BOOLEAN NOT NULL DEFAULT true,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "LabTestParameter_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "LabOrderItem" (
  "id" TEXT NOT NULL,
  "tenantId" TEXT NOT NULL,
  "encounterId" TEXT NOT NULL,
  "testId" TEXT NOT NULL,
  "status" "LabOrderItemStatus" NOT NULL DEFAULT 'ORDERED',
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "LabOrderItem_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "LabResultItem" (
  "id" TEXT NOT NULL,
  "tenantId" TEXT NOT NULL,
  "orderItemId" TEXT NOT NULL,
  "parameterId" TEXT NOT NULL,
  "value" TEXT NOT NULL,
  "valueNumeric" DOUBLE PRECISION,
  "flag" "LabResultFlag" NOT NULL DEFAULT 'UNKNOWN',
  "enteredBy" TEXT,
  "enteredAt" TIMESTAMP(3),
  "verifiedBy" TEXT,
  "verifiedAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "LabResultItem_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "LabTestDefinition_tenantId_code_key"
  ON "LabTestDefinition"("tenantId", "code");
CREATE INDEX IF NOT EXISTS "LabTestDefinition_tenantId_active_name_idx"
  ON "LabTestDefinition"("tenantId", "active", "name");

CREATE UNIQUE INDEX IF NOT EXISTS "LabTestParameter_tenantId_testId_name_key"
  ON "LabTestParameter"("tenantId", "testId", "name");
CREATE INDEX IF NOT EXISTS "LabTestParameter_tenantId_testId_displayOrder_idx"
  ON "LabTestParameter"("tenantId", "testId", "displayOrder");

CREATE UNIQUE INDEX IF NOT EXISTS "LabOrderItem_tenantId_encounterId_testId_key"
  ON "LabOrderItem"("tenantId", "encounterId", "testId");
CREATE INDEX IF NOT EXISTS "LabOrderItem_tenantId_encounterId_status_idx"
  ON "LabOrderItem"("tenantId", "encounterId", "status");

CREATE UNIQUE INDEX IF NOT EXISTS "LabResultItem_tenantId_orderItemId_parameterId_key"
  ON "LabResultItem"("tenantId", "orderItemId", "parameterId");
CREATE INDEX IF NOT EXISTS "LabResultItem_tenantId_orderItemId_idx"
  ON "LabResultItem"("tenantId", "orderItemId");

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'LabTestDefinition_tenantId_fkey') THEN
    ALTER TABLE "LabTestDefinition"
      ADD CONSTRAINT "LabTestDefinition_tenantId_fkey"
      FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'LabTestParameter_tenantId_fkey') THEN
    ALTER TABLE "LabTestParameter"
      ADD CONSTRAINT "LabTestParameter_tenantId_fkey"
      FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'LabTestParameter_testId_fkey') THEN
    ALTER TABLE "LabTestParameter"
      ADD CONSTRAINT "LabTestParameter_testId_fkey"
      FOREIGN KEY ("testId") REFERENCES "LabTestDefinition"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'LabOrderItem_tenantId_fkey') THEN
    ALTER TABLE "LabOrderItem"
      ADD CONSTRAINT "LabOrderItem_tenantId_fkey"
      FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'LabOrderItem_encounterId_fkey') THEN
    ALTER TABLE "LabOrderItem"
      ADD CONSTRAINT "LabOrderItem_encounterId_fkey"
      FOREIGN KEY ("encounterId") REFERENCES "Encounter"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'LabOrderItem_testId_fkey') THEN
    ALTER TABLE "LabOrderItem"
      ADD CONSTRAINT "LabOrderItem_testId_fkey"
      FOREIGN KEY ("testId") REFERENCES "LabTestDefinition"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'LabResultItem_tenantId_fkey') THEN
    ALTER TABLE "LabResultItem"
      ADD CONSTRAINT "LabResultItem_tenantId_fkey"
      FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'LabResultItem_orderItemId_fkey') THEN
    ALTER TABLE "LabResultItem"
      ADD CONSTRAINT "LabResultItem_orderItemId_fkey"
      FOREIGN KEY ("orderItemId") REFERENCES "LabOrderItem"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'LabResultItem_parameterId_fkey') THEN
    ALTER TABLE "LabResultItem"
      ADD CONSTRAINT "LabResultItem_parameterId_fkey"
      FOREIGN KEY ("parameterId") REFERENCES "LabTestParameter"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
  END IF;
END $$;
