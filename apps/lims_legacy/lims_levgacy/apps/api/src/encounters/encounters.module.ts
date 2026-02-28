import { Module } from '@nestjs/common';
import { DocumentsModule } from '../documents/documents.module';
import { PaymentsModule } from '../payments/payments.module';
import { PrismaModule } from '../prisma/prisma.module';
import { EncountersController } from './encounters.controller';
import { EncountersService } from './encounters.service';
import { LimsCommandsController } from './lims-commands.controller';

@Module({
  imports: [PrismaModule, DocumentsModule, PaymentsModule],
  controllers: [EncountersController, LimsCommandsController],
  providers: [EncountersService],
})
export class EncountersModule {}
