module app;

import std.algorithm : filter;
import std.array : array, join;
import std.file : exists, mkdirRecurse, write, readText;
import std.getopt : config, defaultGetoptPrinter, getopt;
import std.path : dirName;
import std.stdio : stderr, writeln, writefln;
import std.string : strip;

import assoc;

enum string versionText = import("version.txt").strip;

int main(string[] args)
{
    if (args.length <= 1)
    {
        printHelp();
        return 0;
    }

    immutable cmd = args[1];
    auto rest = args[0] ~ args[2 .. $];

    try
    {
        switch (cmd)
        {
        case "help", "--help", "-h":
            printHelp();
            return 0;
        case "version", "--version", "-V":
            writefln("switchyard %s", versionText);
            return 0;
        case "doctor":
            return cmdDoctor();
        case "show":
            return cmdShow(args[2 .. $]);
        case "snapshot":
            return cmdSnapshot(rest);
        case "status":
            return cmdStatus(rest);
        case "lock-icons":
            stderr.writeln("lock-icons: not implemented yet (see PLAN.adoc)");
            return 2;
        case "restore":
            stderr.writeln("restore: not implemented yet (see PLAN.adoc)");
            return 2;
        default:
            stderr.writefln("unknown command: %s", cmd);
            printHelp();
            return 1;
        }
    }
    catch (Exception e)
    {
        stderr.writefln("error: %s", e.msg);
        return 1;
    }
}

int cmdShow(string[] exts)
{
    if (!exts.length)
    {
        stderr.writeln("usage: switchyard show <.ext> [<.ext>...]");
        return 1;
    }
    foreach (ext; exts)
        writeln(formatSnapshot(readAssoc(ext)));
    return 0;
}

int cmdSnapshot(string[] args)
{
    string outPath;
    auto helpInfo = getopt(args,
        config.caseSensitive,
        "o|out", "Write snapshot to PATH", &outPath);

    if (helpInfo.helpWanted)
    {
        defaultGetoptPrinter("usage: switchyard snapshot [--out PATH] <.ext>...", helpInfo.options);
        return 0;
    }

    auto exts = args[1 .. $].filter!(a => a.length && a[0] != '-').array;
    if (!exts.length)
    {
        stderr.writeln("usage: switchyard snapshot [--out PATH] <.ext> [<.ext>...]");
        return 1;
    }

    import std.algorithm : map;

    auto body = exts.map!(e => formatSnapshot(readAssoc(e))).join("\n");
    if (outPath.length)
    {
        auto parent = dirName(outPath);
        if (parent.length && parent != "." && !exists(parent))
            mkdirRecurse(parent);
        write(outPath, body);
        writefln("wrote %s", outPath);
    }
    else
        writeln(body);
    return 0;
}

int cmdStatus(string[] args)
{
    string snapPath;
    auto helpInfo = getopt(args,
        "s|snapshot", "Path to a prior snapshot file", &snapPath);

    if (helpInfo.helpWanted || !snapPath.length)
    {
        stderr.writeln("usage: switchyard status --snapshot PATH");
        stderr.writeln("(full live-vs-snapshot diff planned; currently echoes the file)");
        return snapPath.length ? 0 : 1;
    }
    if (!exists(snapPath))
    {
        stderr.writefln("snapshot not found: %s", snapPath);
        return 1;
    }
    writeln("# status: full diff not implemented; snapshot file follows");
    writeln(readText(snapPath));
    return 0;
}

int cmdDoctor()
{
    writefln("switchyard %s", versionText);
    writeln("os: windows");
    writeln("role: association switchyard (open / icon / thumbnail tracks)");
    writeln("config: (none yet — SDL watchlist planned)");
    writeln("data: %LOCALAPPDATA%\\Dev-Centr\\Switchyard (planned)");
    return 0;
}

void printHelp()
{
    writeln("Switchyard — Windows file-association switchyard");
    writeln;
    writeln("Usage:");
    writeln("  switchyard show <.ext> [<.ext>...]");
    writeln("  switchyard snapshot [--out PATH] <.ext> [<.ext>...]");
    writeln("  switchyard status --snapshot PATH");
    writeln("  switchyard lock-icons   (planned)");
    writeln("  switchyard restore      (planned)");
    writeln("  switchyard doctor");
    writeln("  switchyard version");
    writeln;
    writeln("See PLAN.adoc and README.adoc.");
}
