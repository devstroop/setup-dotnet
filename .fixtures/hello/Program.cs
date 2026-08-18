using System;

var major = Environment.Version.Major;
if (major < 6)
{
    Console.Error.WriteLine($"unexpected runtime: {Environment.Version}");
    Environment.Exit(1);
}

Console.WriteLine($"hello from .NET {Environment.Version}");
if (Environment.GetEnvironmentVariable("DOTNET_ROOT") is not { Length: > 0 } root)
{
    Console.Error.WriteLine("DOTNET_ROOT env var not set");
    Environment.Exit(1);
}
Console.WriteLine($"DOTNET_ROOT={root}");