FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY ["PdfService.csproj", "./"]
RUN dotnet restore "PdfService.csproj"
COPY . .
RUN dotnet publish "PdfService.csproj" -c Release -o /app/publish

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final
WORKDIR /app
COPY --from=build /app/publish .
# Install libfontconfig1 for SkiaSharp/QuestPDF if needed (check base image)
RUN apt-get update && apt-get install -y libfontconfig1
ENTRYPOINT ["dotnet", "PdfService.dll"]
