import {
  IsBoolean,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  MinLength,
} from 'class-validator';

export class AddParameterDto {
  @IsString()
  @MinLength(1)
  name: string;

  @IsString()
  @IsOptional()
  unit?: string;

  @IsNumber()
  @IsOptional()
  refLow?: number;

  @IsNumber()
  @IsOptional()
  refHigh?: number;

  @IsString()
  @IsOptional()
  refText?: string;

  @IsInt()
  @IsOptional()
  displayOrder?: number;

  @IsBoolean()
  @IsOptional()
  active?: boolean;
}
