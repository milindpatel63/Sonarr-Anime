# syntax=docker/dockerfile:1.6

ARG DOTNET_SDK_VERSION
ARG DOTNET_RUNTIME_VERSION

# ---------- Frontend ----------
FROM node:20-alpine AS frontend
WORKDIR /build
COPY package.json yarn.lock* tsconfig.json ./
RUN yarn install --frozen-lockfile
COPY frontend ./frontend
RUN yarn build

# ---------- Backend ----------
FROM mcr.microsoft.com/dotnet/sdk:${DOTNET_RUNTIME_VERSION} AS backend
WORKDIR /build

COPY global.json ./
COPY Logo ./Logo/
COPY src/ ./src/

# Fail fast if SDK required by global.json is not usable
RUN dotnet --version | grep -q "${DOTNET_SDK_VERSION}" || \
    (echo "Expected SDK ${DOTNET_SDK_VERSION}, got $(dotnet --version)" && exit 1)

RUN dotnet restore src/Sonarr.sln

COPY --from=frontend /build/_output/UI ./_output/UI

WORKDIR /build/src/NzbDrone.Mono
RUN dotnet publish -c Release -o /app -r linux-x64 --self-contained false \
    -p:TreatWarningsAsErrors=false \
    -p:RunAnalyzersDuringBuild=false

WORKDIR /build/src/NzbDrone.Console
RUN dotnet publish -c Release -o /app -r linux-x64 --self-contained false \
    -p:TreatWarningsAsErrors=false \
    -p:RunAnalyzersDuringBuild=false && \
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
