/** 
 * Authors: Danny Arends
 * License: GPL-v3 (See accompanying file LICENSE.txt or copy at https://www.gnu.org/licenses/gpl-3.0.en.html)
 */

import std.file : isDir, write;
import std.format : format;
import std.json : JSONValue;
import std.process : executeShell;
import std.string : strip, toLower, indexOf;

import files : getTempPath;
import tools : Tool, RegisterTools;
import utils;

mixin RegisterTools;

string dockerFmt = "docker run --rm --memory 1024m --cpus 2.0 --stop-timeout 30 --ulimit nofile=1024:1024 -v %s:/code:ro -v %s:/workspace %s %s 2>&1";

@Tool("Execute code located at path in an isolated Docker sandbox, make sure path is an absolute path. Supported languages: 
Python, Javascript, Bash, D, and R.")
string runCode(string language, string path) {
  if (!isSafePath(path, "w")) return(format("Error: path outside allowed directory: '%s'", CWD));
  if (!exists(path)) return(format("Error: file '%s' does not exist", path));
  if (isDir(path)) return(format("Error: path '%s' is a directory, not a file", path));
  try {
    string image;
    string cmd;
    switch (language.toLower()) {
      case "python":     image = "dllm-python";    cmd = "sh -c \"cd /workspace && python3 /code\"";  break;
      case "javascript": image = "node:alpine";    cmd = "sh -c \"cd /workspace && node /code\"";     break;
      case "bash":       image = "alpine";         cmd = "sh -c \"cd /workspace && sh /code\"";       break;
      case "r":          image = "r-base";         cmd = "sh -c \"cd /workspace && Rscript /code\"";  break;
      case "d":          image = "dlanguage/dmd";  cmd = "sh -c \"cd /workspace && dmd -run /code\""; break;
      default: return(format("Error: unsupported language '%s'", language));
    }

    string docker = format(dockerFmt, path, CWD, image, cmd);
    auto result = executeShell(docker);
    return(JSONValue([
      "exit_code": JSONValue(result.status),
      "output":    JSONValue(result.output.strip())
    ]).toString());
  } catch (Exception e) { return(format("Error: %s", e.msg)); }
}

// Build a Python image which has standard python stuff inside it
// If we need to update, run: docker rmi dllm-python
void ensurePythonImage(string tag = "dllm-python") {
  // Check if image exists
  auto check = executeShell("docker images -q " ~ tag);
  if (check.output.strip().length > 0) return;

  // Build from inline Dockerfile
  writeln("[docker] Building Python sandbox image...");
  string dockerfile = "FROM python:3.12-slim\n
                       RUN apt-get update && apt-get install -y lame ffmpeg && rm -rf /var/lib/apt/lists/*\n
                       RUN pip install --no-cache-dir numpy scipy pandas matplotlib scikit-learn gtts pydub\n";
  auto tmp = getTempPath("Dockerfile", "dock");  // no extension
  tmp.write(dockerfile);
  auto call = "docker build -t " ~ tag ~ " -f " ~ tmp ~ " .";
  writeln(call);
  auto result = executeShell(call);
  if (result.status != 0) writeln("[docker] Build failed: ", result.output);
}
