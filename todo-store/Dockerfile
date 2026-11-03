# ---- Build stage: .NET SDK 6.0.425 (latest .NET 6 SDK image on MCR) ----
FROM mcr.microsoft.com/dotnet/sdk:6.0.425 AS build
WORKDIR /src
COPY global.json .
COPY src/TodoStore/TodoStore.csproj src/TodoStore/
RUN dotnet restore src/TodoStore/TodoStore.csproj
COPY src/ src/
RUN dotnet publish src/TodoStore/TodoStore.csproj -c Release -o /app --no-restore

# ---- Runtime stage: ASP.NET Core 6.0.36 ----
FROM mcr.microsoft.com/dotnet/aspnet:6.0.36 AS runtime
WORKDIR /app
COPY --from=build /app .
ENV ASPNETCORE_URLS=http://+:7124
EXPOSE 7124
USER 1000
ENTRYPOINT ["dotnet", "TodoStore.dll"]
