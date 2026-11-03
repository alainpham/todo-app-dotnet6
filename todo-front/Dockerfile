# ---- Build stage: .NET SDK 6.0.425 (latest .NET 6 SDK image on MCR) ----
FROM mcr.microsoft.com/dotnet/sdk:6.0.425 AS build
WORKDIR /src
COPY global.json .
COPY src/HelloWorld/HelloWorld.csproj src/HelloWorld/
RUN dotnet restore src/HelloWorld/HelloWorld.csproj
COPY src/ src/
RUN dotnet publish src/HelloWorld/HelloWorld.csproj -c Release -o /app --no-restore

# ---- Runtime stage: ASP.NET Core 6.0.36 ----
FROM mcr.microsoft.com/dotnet/aspnet:6.0.36 AS runtime
WORKDIR /app
COPY --from=build /app .
ENV ASPNETCORE_URLS=http://+:7123
EXPOSE 7123
USER 1000
ENTRYPOINT ["dotnet", "HelloWorld.dll"]
