// Adapted from LandoriaModsAutomation/scripts/ci/ValheimGameVersion.
using System.Reflection;
using System.Runtime.Loader;

if (args.Length != 1 || !File.Exists(args[0]))
{
    Console.Error.WriteLine("Usage: ValheimGameVersion <assembly_valheim.dll>");
    return 2;
}

string assemblyPath = Path.GetFullPath(args[0]);
string directory = Path.GetDirectoryName(assemblyPath)!;
AssemblyLoadContext.Default.Resolving += (_, name) =>
{
    string dependency = Path.Combine(directory, $"{name.Name}.dll");
    return File.Exists(dependency) ? AssemblyLoadContext.Default.LoadFromAssemblyPath(dependency) : null;
};

Assembly assembly = AssemblyLoadContext.Default.LoadFromAssemblyPath(assemblyPath);
Type versionType = assembly.GetType("Version", throwOnError: true)!;
object version = versionType.GetProperty("CurrentVersion", BindingFlags.Public | BindingFlags.Static)!.GetValue(null)!;
Type gameVersionType = version.GetType();
int major = (int)gameVersionType.GetField("m_major")!.GetValue(version)!;
int minor = (int)gameVersionType.GetField("m_minor")!.GetValue(version)!;
int patch = (int)gameVersionType.GetField("m_patch")!.GetValue(version)!;
Console.WriteLine($"{major}.{minor}.{patch}");
return 0;
