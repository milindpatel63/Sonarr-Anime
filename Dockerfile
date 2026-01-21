# Build frontend
FROM node:20-alpine AS frontend
WORKDIR /build
COPY package.json yarn.lock* tsconfig.json ./
RUN yarn install --frozen-lockfile
COPY frontend ./frontend
RUN yarn build

# Build backend
FROM mcr.microsoft.com/dotnet/sdk:6.0.405 AS backend
WORKDIR /build
COPY global.json ./
COPY Logo ./Logo/
COPY src/ ./src/
RUN dotnet restore src/Sonarr.sln
COPY --from=frontend /build/_output/UI ./_output/UI
WORKDIR /build/src/NzbDrone.Mono
RUN dotnet publish -c Release -f net6.0.405 -o /app -r linux-x64 --self-contained false \
    -p:TreatWarningsAsErrors=false \
    -p:RunAnalyzersDuringBuild=false
WORKDIR /build/src/NzbDrone.Console
RUN dotnet publish -c Release -f net6.0.405 -o /app -r linux-x64 --self-contained false \
    -p:TreatWarningsAsErrors=false \
    -p:RunAnalyzersDuringBuild=false && \
    cp -r /build/_output/UI /app/UI

# Runtime image
FROM mcr.microsoft.com/dotnet/aspnet:6.0.405
WORKDIR /app

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        sqlite3 \
        mediainfo \
        libicu-dev \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=backend /app .

EXPOSE 8989

ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false

VOLUME ["/config"]

ENTRYPOINT ["./Sonarr", "-data=/config"]
