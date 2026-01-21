# syntax=docker/dockerfile:1.6

ARG DOTNET_SDK_VERSION
ARG DOTNET_RUNTIME_VERSION
ARG DOTNET_TFM

# ---------- Frontend ----------
FROM node:20-alpine AS frontend
WORKDIR /build
COPY package.json yarn.lock* tsconfig.json ./
RUN yarn install --frozen-lockfile
COPY frontend ./frontend
RUN yarn build

# ---------- Backend ----------
FROM mcr.microsoft.com/dotnet/sdk:${DOTNET_SDK_VERSION} AS backend
WORKDIR /build

COPY global.json ./
COPY Logo ./Logo/
COPY src/ ./src/

RUN dotnet restore src/Sonarr.sln

COPY --from=frontend /build/_output/UI ./_output/UI

# ---- Sonarr.Mono ----
WORKDIR /build/src/NzbDrone.Mono
RUN dotnet publish \
    --configuration Release \
    --framework ${DOTNET_TFM} \
    --runtime linux-x64 \
    --self-contained false \
    --output /app \
    -p:TreatWarningsAsErrors=false \
    -p:RunAnalyzersDuringBuild=false \
    Sonarr.Mono.csproj

# ---- Sonarr.Console ----
WORKDIR /build/src/NzbDrone.Console
RUN dotnet publish \
    --configuration Release \
    --framework ${DOTNET_TFM} \
    --runtime linux-x64 \
    --self-contained false \
    --output /app \
    -p:TreatWarningsAsErrors=false \
    -p:RunAnalyzersDuringBuild=false \
    Sonarr.Console.csproj && \
    cp -r /build/_output/UI /app/UI

# ---------- Runtime ----------
FROM mcr.microsoft.com/dotnet/aspnet:${DOTNET_RUNTIME_VERSION}
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
