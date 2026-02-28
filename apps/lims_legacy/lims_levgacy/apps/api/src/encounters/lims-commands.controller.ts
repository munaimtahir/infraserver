import {
  Body,
  Controller,
  HttpCode,
  HttpStatus,
  Post,
  UseGuards,
} from '@nestjs/common';
import { TenantGuard } from '../common/guards/tenant.guard';
import { UpdateEncounterPrepCommandDto } from './dto/update-encounter-prep-command.dto';
import { EncountersService } from './encounters.service';

@Controller('lims/commands')
@UseGuards(TenantGuard)
export class LimsCommandsController {
  constructor(private readonly encountersService: EncountersService) {}

  @Post('updateEncounterPrep')
  @HttpCode(HttpStatus.OK)
  updateEncounterPrep(@Body() dto: UpdateEncounterPrepCommandDto) {
    return this.encountersService.updateEncounterPrepCommand(dto);
  }
}
