using System.Collections.Concurrent;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddSingleton<TodoStore>();
var app = builder.Build();

app.MapGet("/api/todos", (TodoStore store) => store.All());

app.MapGet("/api/todos/{id:int}", (int id, TodoStore store) =>
    store.Get(id) is { } todo ? Results.Ok(todo) : Results.NotFound());

app.MapPost("/api/todos", (TodoInput input, TodoStore store) =>
{
    if (string.IsNullOrWhiteSpace(input.Title))
        return Results.BadRequest("title is required");
    var todo = store.Add(input.Title.Trim());
    return Results.Created($"/api/todos/{todo.Id}", todo);
});

app.MapPut("/api/todos/{id:int}", (int id, TodoUpdate update, TodoStore store) =>
    store.Update(id, update) is { } todo ? Results.Ok(todo) : Results.NotFound());

app.MapDelete("/api/todos/{id:int}", (int id, TodoStore store) =>
    store.Remove(id) ? Results.NoContent() : Results.NotFound());

// Liveness / readiness probes for Kubernetes
app.MapGet("/healthz", () => Results.Ok("healthy"));

app.Run();

record Todo(int Id, string Title, bool Done, DateTime CreatedAt);
record TodoInput(string? Title);
record TodoUpdate(string? Title, bool? Done);

// In-memory store: data lives only as long as the process (one copy per pod).
class TodoStore
{
    private readonly ConcurrentDictionary<int, Todo> _items = new();
    private int _nextId;

    public IEnumerable<Todo> All() => _items.Values.OrderBy(t => t.Id);

    public Todo? Get(int id) => _items.TryGetValue(id, out var t) ? t : null;

    public Todo Add(string title)
    {
        var todo = new Todo(Interlocked.Increment(ref _nextId), title, false, DateTime.UtcNow);
        _items[todo.Id] = todo;
        return todo;
    }

    public Todo? Update(int id, TodoUpdate update)
    {
        while (_items.TryGetValue(id, out var current))
        {
            var title = string.IsNullOrWhiteSpace(update.Title) ? current.Title : update.Title.Trim();
            var next = current with { Title = title, Done = update.Done ?? current.Done };
            if (_items.TryUpdate(id, next, current))
                return next;
        }
        return null;
    }

    public bool Remove(int id) => _items.TryRemove(id, out _);
}
