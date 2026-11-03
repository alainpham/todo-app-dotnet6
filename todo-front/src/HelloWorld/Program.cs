var builder = WebApplication.CreateBuilder(args);

// Todos live in the todo-store service; this app serves the UI and forwards /api/todos calls.
// Plain HTTP on purpose so Beyla can propagate trace context between the two services.
var storeUrl = builder.Configuration["TODO_STORE_URL"] ?? "http://todo-store";
builder.Services.AddHttpClient("todo-store", c => c.BaseAddress = new Uri(storeUrl));
var app = builder.Build();

// Serves wwwroot/index.html at "/"
app.UseDefaultFiles();
app.UseStaticFiles();

app.MapGet("/api/todos", (HttpContext ctx, IHttpClientFactory http) =>
    Forward(ctx, http, HttpMethod.Get, "/api/todos"));

app.MapGet("/api/todos/{id:int}", (int id, HttpContext ctx, IHttpClientFactory http) =>
    Forward(ctx, http, HttpMethod.Get, $"/api/todos/{id}"));

app.MapPost("/api/todos", (HttpContext ctx, IHttpClientFactory http) =>
    Forward(ctx, http, HttpMethod.Post, "/api/todos"));

app.MapPut("/api/todos/{id:int}", (int id, HttpContext ctx, IHttpClientFactory http) =>
    Forward(ctx, http, HttpMethod.Put, $"/api/todos/{id}"));

app.MapDelete("/api/todos/{id:int}", (int id, HttpContext ctx, IHttpClientFactory http) =>
    Forward(ctx, http, HttpMethod.Delete, $"/api/todos/{id}"));

// Liveness / readiness probes for Kubernetes (local only, does not call todo-store)
app.MapGet("/healthz", () => Results.Ok("healthy"));

app.Run();

// Relays the incoming request body to todo-store and copies status, content type and body back.
static async Task Forward(HttpContext ctx, IHttpClientFactory http, HttpMethod method, string path)
{
    using var request = new HttpRequestMessage(method, path);
    if (method == HttpMethod.Post || method == HttpMethod.Put)
    {
        request.Content = new StreamContent(ctx.Request.Body);
        if (ctx.Request.ContentType is { } contentType)
            request.Content.Headers.TryAddWithoutValidation("Content-Type", contentType);
    }

    HttpResponseMessage response;
    try
    {
        response = await http.CreateClient("todo-store").SendAsync(request, ctx.RequestAborted);
    }
    catch (HttpRequestException ex)
    {
        ctx.Response.StatusCode = StatusCodes.Status502BadGateway;
        await ctx.Response.WriteAsync($"todo-store unavailable: {ex.Message}");
        return;
    }

    using (response)
    {
        ctx.Response.StatusCode = (int)response.StatusCode;
        // 204 / 304 must not carry a body; Kestrel throws if we write one
        if (ctx.Response.StatusCode is StatusCodes.Status204NoContent or StatusCodes.Status304NotModified)
            return;
        if (response.Content.Headers.ContentType is { } responseType)
            ctx.Response.ContentType = responseType.ToString();
        await response.Content.CopyToAsync(ctx.Response.Body);
    }
}
