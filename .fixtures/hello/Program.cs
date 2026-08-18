using System;

var major = Environment.Version.Major;
if (major < 6)
{
    Console.Error.WriteLine($"unexpected runtime: {Environment.Version}");
    Environment.Exit(1);
}

Console.WriteLine($"hello from .NET {Environment.Version}");
var root = Environment.GetEnvironmentVariable("DOTNET_ROOT") ?? "";
if (root.Length == 0)
{
    Console.Error.WriteLine("DOTNET_ROOT env var not set");
    Environment.Exit(1);
}
Console.WriteLine($"DOTNET_ROOT={root}");