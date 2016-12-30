module priv.cmd;

import std.algorithm;
import std.conv;
import std.file;
import std.format;
import std.getopt;
import std.json;
import std.process;
import std.random;
import std.range;
import std.regex;
import std.stdio;
import std.string;

import tinyredis;

struct PrivCmdOptions {
    string add;
    string remove;

    bool validate(ref string message) {
        message = "ye is gud";
        return true;
    }
}

string username;
string envName;

Redis redisMaster;
Redis redisLocal;

// Example hosts entry: 172.24.0.1  priv-dark-desktop  priv-dark-local
string getEnvName() {
    ulong prefixLength = ("priv-" ~ username ~ "-").length;

    return readText("/etc/hosts")
        .splitLines()                                       // Get array of host entries
        .filter!( line => line != "" && line[0] != '#'    ) // Filter away comments and empty lines
        .map!(    line => line.split()                    ) // Split lines into arrays of entries
        .find!(   line => line.canFind("priv-dark-local") ) // Find line containing "priv-user-local" entry
        .array[0].array[1]                                  // Get the hostname for the first matching entry
        .drop(prefixLength);                                // Get hostname
}

void addBookmark(string command) {
    redisMaster.send("SADD", "commands", command);
}

void removeBookmark(string command) {
    redisMaster.send("SREM", "commands", command);
    redisMaster.send("SREM", "commands:" ~ envName, command);
}

void addLocalBookmark(string command) {
    redisMaster.send("SADD", "commands:" ~ envName, command);
}

void makeLocalBookmark(string command) {
    redisMaster.send("SREM", "commands", command);
    redisMaster.send("SADD", "commands:" ~ envName, command);
}

void makeGlobalBookmark(string command) {
    redisMaster.send("SREM", "commands:" ~ envName, command);
    redisMaster.send("SADD", "commands", command);
}

void showCommandMenu() {
    auto commands = redisLocal.send("SUNION", "commands", "commands:" ~ envName).values;
    commands.randomShuffle();

    string[] dmenuCmd = [ "dmenu", "-p", "Run", "-nf", "#5433d6", "-sb", "#221556" ];
    auto dmenu = pipeProcess(dmenuCmd, Redirect.stdin | Redirect.stdout);
    foreach (command; commands) dmenu.stdin.writeln(command);
    dmenu.stdin.flush();
    dmenu.stdin.close();

    foreach (command; dmenu.stdout.byLine().map!(to!string)) {
        if (command[0] == '-') {
            long spaceIndex = command.indexOf(' ');
            string dashCmd   = command[0..(spaceIndex)];
            string cmdTarget = command.drop(spaceIndex + 1);

            switch (dashCmd) {
                case "--add":
                case "-a":  addBookmark(cmdTarget);      break;

                case "--remove":
                case "-r":  removeBookmark(cmdTarget);   break;

                case "--add-local":
                case "-al": addLocalBookmark(cmdTarget); break;

                case "--make-local":
                case "-ml":  makeLocalBookmark(cmdTarget);   break;

                case "--make-global":
                case "-mg":  makeGlobalBookmark(cmdTarget);   break;

                default: break;
            }

            showCommandMenu();
        } else {
            executeShell(command);
        }
    }

    wait(dmenu.pid);
}

int main(string[] args) {
    username = environment["USER"];
    envName = getEnvName();

    redisMaster = new Redis("priv-dark-master", 6379);
    redisLocal = new Redis("priv-dark-local", 6379);

    showCommandMenu();

    return 0;
}
