/** 
 * Authors: Danny Arends
 * License: GPL-v3 (See accompanying file LICENSE.txt or copy at https://www.gnu.org/licenses/gpl-3.0.en.html)
 */
module tools;

import std.algorithm : map;
import std.array : appender, array, join;
import std.format : format;
import std.json : JSONValue, parseJSON;
import std.regex : regex, matchAll;
import std.stdio : writefln;

// UDA for marking tool functions
struct Tool {
  string description;
}

// Tool parameter definition
struct ToolParam {
  string name;
  string type;
}

// Tool definition
struct ToolDef {
  string name;
  string description;
  ToolParam[] parameters;
  string function(JSONValue) executor;
}

// Tool Call definition
struct ToolCall {
  string name;
  JSONValue arguments;
}

// Tool registry
__gshared ToolDef[] ALL_TOOLS;

// Mixin template to auto-register all @Tool functions in a module
mixin template RegisterTools() {
  static this() {
    import tools : ALL_TOOLS, Tool, ToolDef, ToolParam;
    import std.conv : to;
    import std.traits : hasUDA, getUDAs, ParameterIdentifierTuple;
    import std.json : JSONValue, JSONType;
    import std.array : join;

    // Get reference to current module an scan all functions for UDAs
    mixin("alias ThisModule = " ~ __MODULE__ ~ ";");

    static foreach(name; __traits(allMembers, ThisModule)) {{
      static if (name != "object" && name != "ThisModule") {
        mixin("alias member = " ~ name ~ ";");
        static if (is(typeof(member) == function)) {
          static if (hasUDA!(member, Tool)) {
            // Get the tool description, parameters, and executor
            enum description = getUDAs!(member, Tool)[0].description;
            alias ParamNames = ParameterIdentifierTuple!member;

            ToolParam[] parameters;
            static foreach(paramName; ParamNames) { parameters ~= ToolParam(paramName, "string"); }

            // Build the tool executor
            auto executor = (JSONValue args) {
              static foreach(paramName; ParamNames) {
                if (paramName !in args) { return(format("Error: Missing parameter '%s'",paramName)); }
              }

              string[] argValues;
              static foreach(paramName; ParamNames) { 
                argValues ~= args[paramName].type == JSONType.string ? args[paramName].str : args[paramName].toString(); 
              }
              enum callStr = {
                  string[] argRefs;
                  static foreach(i; 0 .. ParamNames.length) { argRefs ~= "argValues[" ~ i.to!string ~ "]"; }
                  return "return member(" ~ argRefs.join(", ") ~ ");";
              }();
              mixin(callStr);
            };
            ALL_TOOLS ~= ToolDef(name, description, parameters, executor);
          }
        }
      }
    }}
  }
}

// Parse tool call from model output
ToolCall[] parse(string response) {
  ToolCall[] calls;
  auto pattern = regex(r"<tool_call>\s*(\{.*?\})\s*</tool_call>", "gs");
  foreach(match; matchAll(response, pattern)) {
    try {
      JSONValue json = parseJSON(match[1].map!(c => c < 0x20 ? ' ' : c).array);
      if ("name" in json && "arguments" in json) { calls ~= ToolCall(json["name"].str, json["arguments"]); }
    } catch (Exception e) {
      writefln("Failed to parse tool call: %s", e.msg);
    }
  }
  return(calls);
}

string buildJsonGrammar() {
  auto names = ALL_TOOLS.map!(t => "\"\\\"" ~ t.name ~ "\\\"\"").join(" | ");
  return(`
root ::= "{" ws "\"name\"" ws ":" ws toolname ws "," ws "\"arguments\"" ws ":" ws object ws "}</tool_call>"
toolname ::= ` ~ names ~ `
object ::= "{" ws (string ws ":" ws value (ws "," ws string ws ":" ws value)*)? ws "}"
array ::= "[" ws (value (ws "," ws value)*)? ws "]"
value ::= string | number | object | array | "true" | "false" | "null"
string ::= "\"" ([^"\\] | "\\" (["\\/bfnrt] | "u" [0-9a-fA-F] [0-9a-fA-F] [0-9a-fA-F] [0-9a-fA-F]))* "\""
number ::= "-"? ([0-9] | [1-9] [0-9]+) ("." [0-9]+)? ([eE] [-+]? [0-9]+)?
ws ::= [ \t\n\r]*
`);
}

// Execute tool by name with JSON arguments
string executeTool(string toolName, JSONValue args) {
  try {
    foreach(tool; ALL_TOOLS) {
      if (tool.name == toolName) return(tool.executor(args));
    }
    return("Error: unknown tool '" ~ toolName ~ "'");
  } catch (Exception e) { return(format("Error executing tool: %s", e.msg)); }
}

// Generate tools JSON for system prompt
string toolsToJSON() {
  auto result = appender!string;

  result ~= "[";
  foreach(i, tool; ALL_TOOLS) {
    if (i > 0) result ~= ",";

    JSONValue properties = JSONValue.emptyObject;
    foreach(param; tool.parameters) { properties[param.name] = JSONValue(["type": JSONValue(param.type)]); }

    JSONValue toolJson = JSONValue([
      "name": JSONValue(tool.name),
      "description": JSONValue(tool.description),
      "parameters": JSONValue(["type": JSONValue("object"),"properties": properties])
    ]);
    result ~= toolJson.toString();
  }
  result ~= "]";
  return(result.data);
}
