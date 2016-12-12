module priv_cmd;

import std.algorithm;
import std.conv;
import std.file;
import std.format;
import std.getopt;
import std.json;
import std.process;
import std.regex;
import std.range;
import std.stdio;
import std.string;

import tinyredis;

struct ScreentoolOptions
{
    bool foo;
    bool bar;

    bool validate(ref string message)
    {
        message = "ye is gud";
        return true;
    }
}

ScreentoolOptions options;

int main(string[] args)
{
    auto helpInfo = getopt(args,
            std.getopt.config.caseSensitive,
            "f|foo", "Use a shortened URL where availible", &options.foo,
            "b|bar", "Don't send notifications",            &options.bar);

    if (helpInfo.helpWanted)
    {
        writeln("priv-cmd v0.1.0");
        writeln("");
        writeln("Options:");

        ulong longestShortOptLength = helpInfo.options.map!( opt => opt.optShort.length )
            .reduce!((a, b) => max(a, b));
        ulong longestLongOptLength  = helpInfo.options.map!( opt => opt.optLong.length  )
            .reduce!((a, b) => max(a, b));

        foreach (it; helpInfo.options)
        {
            writefln("  %*s %*-s %s",
                    longestShortOptLength,    it.optShort,
                    longestLongOptLength + 2, it.optLong,
                    it.help);
        }

        return 0;
    }

    string message;
    if (!options.validate(message))
    {
        writeln(message);
        return 1;
    }

    auto redis = new Redis("priv-dark-novaember", 6379);
    auto commands = redis.send("SMEMBERS", "commands");

    string[] dmenuCmd = [ "dmenu", "-p", "Run", "-nf", "#5433d6", "-sb", "#221556" ];
    auto dmenu = pipeProcess(dmenuCmd, Redirect.stdin | Redirect.stdout);
    foreach (command; commands) dmenu.stdin.writeln(command);
    dmenu.stdin.flush();
    dmenu.stdin.close();

    string cmd = dmenu.stdout.readln();
    executeShell(cmd);

    return 0;
}
