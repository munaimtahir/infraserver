-- Phase 3C: Typed encounter MAIN data per service

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'BbCrossmatchResult') THEN
    CREATE TYPE "BbCrossmatchResult" AS ENUM ('COMPATIBLE', 'INCOMPATIBLE');
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS "LabEncounterMain" (
  "id" TEXT NOT NULL,
  "tenantId" TEXT NOT NULL,
  "encounterId" TEXT NOT NULL,
  "resultSummary" TEXT,
  "verifiedBy" TEXT,
  "verifiedAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "LabEncounterMain_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "RadEncounterMain" (
  "id" TEXT NOT NULL,
  "tenantId" TEXT NOT NULL,
  "encounterId" TEXT NOT NULL,
  "reportText" TEXT,
  "impression" TEXT,
  "radiologistName" TEXT,
  "reportedAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "RadEncounterMain_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "OpdEncounterMain" (
  "id" TEXT NOT NULL,
  "tenantId" TEXT NOT NULL,
  "encounterId" TEXT NOT NULL,
  "chiefComplaint" TEXT,
  "assessment" TEXT,
  "plan" TEXT,
  "prescriptionText" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "OpdEncounterMain_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "BbEncounterMain" (
  "id" TEXT NOT NULL,
  "tenantId" TEXT NOT NULL,
  "encounterId" TEXT NOT NULL,
  "crossmatchResult" "BbCrossmatchResult",
  "componentIssued" TEXT,
  "unitsIssued" INTEGER,
  "issuedAt" TIMESTAMP(3),
  "issueNotes" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "BbEncounterMain_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "IpdEncounterMain" (
  "id" TEXT NOT NULL,
  "tenantId" TEXT NOT NULL,
  "encounterId" TEXT NOT NULL,
  "dailyNote" TEXT,
  "orders" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "IpdEncounterMain_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "LabEncounterMain_tenantId_encounterId_key"
  ON "LabEncounterMain"("tenantId", "encounterId");
CREATE UNIQUE INDEX IF NOT EXISTS "LabEncounterMain_encounterId_key"
  ON "LabEncounterMain"("encounterId");
CREATE UNIQUE INDEX IF NOT EXISTS "RadEncounterMain_tenantId_encounterId_key"
  ON "RadEncounterMain"("tenantId", "encounterId");
CREATE UNIQUE INDEX IF NOT EXISTS "RadEncounterMain_encounterId_key"
  ON "RadEncounterMain"("encounterId");
CREATE UNIQUE INDEX IF NOT EXISTS "OpdEncounterMain_tenantId_encounterId_key"
  ON "OpdEncounterMain"("tenantId", "encounterId");
CREATE UNIQUE INDEX IF NOT EXISTS "OpdEncounterMain_encounterId_key"
  ON "OpdEncounterMain"("encounterId");
CREATE UNIQUE INDEX IF NOT EXISTS "BbEncounterMain_tenantId_encounterId_key"
  ON "BbEncounterMain"("tenantId", "encounterId");
CREATE UNIQUE INDEX IF NOT EXISTS "BbEncounterMain_encounterId_key"
  ON "BbEncounterMain"("encounterId");
CREATE UNIQUE INDEX IF NOT EXISTS "IpdEncounterMain_tenantId_encounterId_key"
  ON "IpdEncounterMain"("tenantId", "encounterId");
CREATE UNIQUE INDEX IF NOT EXISTS "IpdEncounterMain_encounterId_key"
  ON "IpdEncounterMain"("encounterId");

CREATE INDEX IF NOT EXISTS "LabEncounterMain_tenantId_idx" ON "LabEncounterMain"("tenantId");
CREATE INDEX IF NOT EXISTS "RadEncounterMain_tenantId_idx" ON "RadEncounterMain"("tenantId");
CREATE INDEX IF NOT EXISTS "OpdEncounterMain_tenantId_idx" ON "OpdEncounterMain"("tenantId");
CREATE INDEX IF NOT EXISTS "BbEncounterMain_tenantId_idx" ON "BbEncounterMain"("tenantId");
CREATE INDEX IF NOT EXISTS "IpdEncounterMain_tenantId_idx" ON "IpdEncounterMain"("tenantId");

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'LabEncounterMain_tenantId_fkey') THEN
    ALTER TABLE "LabEncounterMain"
      ADD CONSTRAINT "LabEncounterMain_tenantId_fkey"
      FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'LabEncounterMain_encounterId_fkey') THEN
    ALTER TABLE "LabEncounterMain"
      ADD CONSTRAINT "LabEncounterMain_encounterId_fkey"
      FOREIGN KEY ("encounterId") REFERENCES "Encounter"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'RadEncounterMain_tenantId_fkey') THEN
    ALTER TABLE "RadEncounterMain"
      ADD CONSTRAINT "RadEncounterMain_tenantId_fkey"
      FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'RadEncounterMain_encounterId_fkey') THEN
    ALTER TABLE "RadEncounterMain"
      ADD CONSTRAINT "RadEncounterMain_encounterId_fkey"
      FOREIGN KEY ("encounterId") REFERENCES "Encounter"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'OpdEncounterMain_tenantId_fkey') THEN
    ALTER TABLE "OpdEncounterMain"
      ADD CONSTRAINT "OpdEncounterMain_tenantId_fkey"
      FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'OpdEncounterMain_encounterId_fkey') THEN
    ALTER TABLE "OpdEncounterMain"
      ADD CONSTRAINT "OpdEncounterMain_encounterId_fkey"
      FOREIGN KEY ("encounterId") REFERENCES "Encounter"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'BbEncounterMain_tenantId_fkey') THEN
    ALTER TABLE "BbEncounterMain"
      ADD CONSTRAINT "BbEncounterMain_tenantId_fkey"
      FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'BbEncounterMain_encounterId_fkey') THEN
    ALTER TABLE "BbEncounterMain"
      ADD CONSTRAINT "BbEncounterMain_encounterId_fkey"
      FOREIGN KEY ("encounterId") REFERENCES "Encounter"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'IpdEncounterMain_tenantId_fkey') THEN
    ALTER TABLE "IpdEncounterMain"
      ADD CONSTRAINT "IpdEncounterMain_tenantId_fkey"
      FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'IpdEncounterMain_encounterId_fkey') THEN
    ALTER TABLE "IpdEncounterMain"
      ADD CONSTRAINT "IpdEncounterMain_encounterId_fkey"
      FOREIGN KEY ("encounterId") REFERENCES "Encounter"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
  END IF;
END $$;
